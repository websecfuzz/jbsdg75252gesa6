import asyncio
import logging
from datetime import datetime
import os
from zoneinfo import ZoneInfo
import struct
import traceback

# Configuration
#MYSQL_SERVER_HOST = 'db'
MYSQL_SERVER_HOST = os.environ.get('DB_CONTAINER_NAME', "db")
MYSQL_SERVER_PORT = 3306
#PROXY_HOST = '127.0.0.1'
PROXY_HOST = '0.0.0.0'
PROXY_PORT = 3306
WUT_NAME = os.environ.get('WUT_NAME', "")
FOLDER_NAME = os.environ.get('FOLDER_NAME', "/shared-data")
LOG_FILE = f'{FOLDER_NAME}/mysql_proxy_{WUT_NAME}.log'

# MySQL type codes (partial)
MYSQL_TYPES = {
    0x00: "DECIMAL",
    0x01: "TINY",
    0x02: "SHORT",
    0x03: "LONG",
    0x04: "FLOAT",
    0x05: "DOUBLE",
    0x08: "LONGLONG",
    0x0C: "DATETIME",
    0x0D: "TIME",
    0x0F: "VARCHAR",
    0xFD: "VAR_STRING",
    0xFE: "STRING",
}

# Set your timezone here
LOCAL_TIMEZONE = ZoneInfo("Europe/Amsterdam")

class TZFormatter(logging.Formatter):
    def converter(self, timestamp):
        dt = datetime.fromtimestamp(timestamp, LOCAL_TIMEZONE)
        return dt.timetuple()

# Setup logging with timezone-aware timestamps
# formatter = TZFormatter(fmt='%(asctime)s [%(levelname)s] %(message)s')
# formatter = TZFormatter(fmt='[%(levelname)s] %(message)s')
formatter = TZFormatter(fmt='%(message)s')
handler = logging.FileHandler(LOG_FILE)
handler.setFormatter(formatter)

# logging.basicConfig(level=logging.INFO, handlers=[handler])
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(message)s')


# Setup logging
#logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
#logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format=formatter)

def log_query(recv_time, query, addr):
#    logging.info(f"[{addr}] SQL Query: {query}")
    # logging.info(f"[{addr}] ### {query}")
    logging.info(f"{recv_time.strftime('%Y-%m-%d %H:%M:%S,%f')} [INFO] [{addr}] ### {query}")

def log_error(recv_time, error_msg, addr):
    # logging.error(f"[{addr}] ### {error_msg}")
    logging.error(f"{recv_time.strftime('%Y-%m-%d %H:%M:%S,%f')} [ERROR] [{addr}] ### {error_msg}")

def read_lenenc_str(buf, pos):
    first = buf[pos]
    if first < 0xfb:
        length = first
        pos += 1
    elif first == 0xfc:
        length = struct.unpack_from('<H', buf, pos+1)[0]
        pos += 3
    elif first == 0xfd:
        length = struct.unpack_from('<I', buf[pos+1:pos+4] + b'\x00')[0]
        pos += 4
    elif first == 0xfe:
        length = struct.unpack_from('<Q', buf, pos+1)[0]
        pos += 9
    else:
        return None, pos
    s = buf[pos:pos+length].decode('utf-8', errors='replace')
    pos += length
    return s, pos

def parse_param(buf, pos, type_code):
    if type_code in (0x0F, 0xFD, 0xFE):  # VARCHAR/VAR_STRING/STRING
        return read_lenenc_str(buf, pos)
    elif type_code == 0x03:  # LONG
        val = struct.unpack_from('<i', buf, pos)[0]
        return str(val), pos + 4
    elif type_code == 0x08:  # LONGLONG
        val = struct.unpack_from('<q', buf, pos)[0]
        return str(val), pos + 8
    elif type_code == 0x01:  # TINY
        val = buf[pos]
        return str(val), pos + 1
    elif type_code == 0x02:  # SHORT
        val = struct.unpack_from('<h', buf, pos)[0]
        return str(val), pos + 2
    elif type_code == 0x05:  # DOUBLE
        val = struct.unpack_from('<d', buf, pos)[0]
        return str(val), pos + 8
    else:
        return "<unsupported>", pos + 1

class MySQLProxy:
    def __init__(self, mysql_host, mysql_port):
        self.mysql_host = mysql_host
        self.mysql_port = mysql_port
        self.query_info = {}
        self.stmt_map = {}

    async def handle_client(self, client_reader, client_writer):
        addr = client_writer.get_extra_info('peername')

        # Connect to real MySQL server
        try:
            server_reader, server_writer = await asyncio.open_connection(self.mysql_host, self.mysql_port)
        except Exception as e:
            logging.error(f"Failed to connect to MySQL server: {e}")
            client_writer.close()
            await client_writer.wait_closed()
            return

        async def relay(reader, writer, direction="client->server"):
            try:
                while not reader.at_eof():
                # while True:
                    header = await reader.readexactly(4)
                    # length, seq = struct.unpack('<I', header + b'\x00')[0] & 0xFFFFFF, header[3]
                    length = header[0] | (header[1] << 8) | (header[2] << 16)
                    seq = header[3]
                    payload = await reader.readexactly(length)



                    # data = await reader.read(4096)
                    # if not data:
                    #     break

                    # Intercept client->server packets for SQL
                    if direction == "client->server":
                        recv_time = datetime.now()
                        try:
                            # LOCAL_TZ = ZoneInfo("Europe/Amsterdam")  # replace with your timezone
                            # recv_time = datetime.now(LOCAL_TZ)
                            # query = self.extract_sql_query(reader, data)
                            query = self.extract_query(payload)
                            if query:
                                # log_query(recv_time, query, addr)
                                self.query_info[addr] = {
                                    "query": query,
                                    "start_time": recv_time
                                }
                        except Exception as e:
                            log_error(recv_time, f"Malformed packet or unknown structure: {e}", addr)
                            logging.error(traceback.format_exc()[-1000:])

                    elif direction == "server->client":
                        # Check if we have a pending query for this client
                        if addr in self.query_info:
                            # result_str = self.inspect_mysql_response(data)
                            results = self.inspect_sql_response(payload)
                            qinfo = self.query_info.pop(addr)

                            if results and isinstance(results, dict):
                                self.stmt_map[results['stmt_id']] = (qinfo['query'], results['num_params'])
                                result_str = f"OK {results['stmt_id']} {results['num_params']}"
                            else:
                                result_str = results
                            
                            # if result_str:
                            #     logging.info(
                            #         f"[{addr}] Query: {qinfo['query']}\n"
                            #         f"    Result: {result_str}\n"
                            #     )
                            
                            log_query(qinfo['start_time'], f"{qinfo['query']} **{result_str}", addr)

                    # writer.write(data)
                    # await writer.drain()
                    writer.write(header)
                    writer.write(payload)
                    await writer.drain()
            except asyncio.IncompleteReadError as e:
                # Connection closed gracefully
                # logging.error(f"asyncio.IncompleteReadError: {e}")
                pass
            except Exception as e:
                logging.error(f"Relay error [{direction}]: {e}")
                logging.error(traceback.format_exc()[-1000:])
            finally:
                writer.close()

        # Launch bidirectional relays
        await asyncio.gather(
            relay(client_reader, server_writer, "client->server"),
            relay(server_reader, client_writer, "server->client"),
        )

    def extract_query(self, payload) -> str:
        cmd = payload[0]
        if cmd == 0x03:  # COM_QUERY
            sql = payload[1:].decode('utf-8', errors='replace')
            return sql
        elif cmd == 0x16:  # COM_STMT_PREPARE
            sql = payload[1:].decode('utf-8', errors='replace')
            return sql
            # stmt_id is returned by server in the response
        elif cmd == 0x17:  # COM_STMT_EXECUTE
            stmt_id = struct.unpack_from('<I', payload, 1)[0]
            # logging.info(f"STMT_ID: {str(stmt_id)}")
            sql_template, num_params = self.stmt_map.get(stmt_id, ("<unknown>", 0))
            # logging.info(f"num_params: {str(num_params)}")
            if num_params>0:
                pos = 5  # after stmt_id
                pos += 1  # flags
                pos += 4  # iteration count
                null_bitmap_len = (num_params + 7) // 8
                null_bitmap = payload[pos:pos+null_bitmap_len]
                pos += null_bitmap_len
                new_params_bound_flag = payload[pos]
                pos += 1
                params_values = []
                if new_params_bound_flag == 1:
                    types = []
                    for _ in range(num_params):
                        type_code = payload[pos]
                        types.append(type_code)
                        pos += 2  # type code + flags
                    for i in range(num_params):
                        if null_bitmap[i // 8] & (1 << (i % 8)):
                            params_values.append("NULL")
                        else:
                            val, pos = parse_param(payload, pos, types[i])
                            params_values.append(val)

                return f"[COM_STMT_EXECUTE] {stmt_id} {str(params_values)}"

                # # Substitute parameters into SQL
                # filled_sql = sql_template
                # for v in params_values:
                #     filled_sql = filled_sql.replace("?", v, 1)
                # return f"[COM_STMT_EXECUTE] {filled_sql}"
            else:
                return f"[COM_STMT_EXECUTE]"

        return None
    
    def inspect_sql_response(self, payload) -> str:
        # logging.info(f"Header: {str(header)}")
        header = payload[0]
        if payload and payload[0] == 0x00 and len(payload) >= 12:
            dat = {}
            # STMT_PREPARE_OK: byte0=0x00, stmt_id=4 bytes, columns=2 bytes, params=2 bytes
            dat['stmt_id'] = struct.unpack_from('<I', payload, 1)[0]
            dat['num_columns'] = struct.unpack_from('<H', payload, 5)[0]
            dat['num_params'] = struct.unpack_from('<H', payload, 7)[0]

            # logging.info(f"Getting STMT_PREPARE_OK: {str(dat)}")

            return dat

            # # store last SQL seen from client for this stmt_id
            # # WARNING: This assumes COM_STMT_PREPARE was last
            # # In practice, track in client->server branch
            # last_sql = getattr(handle_client, "last_sql", "<unknown>")
            # stmt_map[stmt_id] = (last_sql, num_params)

        if header in (0x00, 0xFE):  # OK packet
            return "OK"
        elif header == 0xFF:  # ERR packet
            ## payload[0] = data[4]
            if len(payload) >= 5:
                err_code = payload[1] | (payload[2] << 8)
                err_msg = payload[5:].decode('utf-8', errors='ignore')
                return f"ERROR {err_code}: {err_msg}"
            return "ERROR: Unknown format"
        else:
            return "Result Set"


        

    def extract_sql_query(self, src_reader, data: bytes) -> str:
        """
        Attempt to extract SQL query from MySQL COM_QUERY packet.
        See MySQL protocol: https://dev.mysql.com/doc/internals/en/com-query.html
        """
        if len(data) < 5:
            return None

        packet_length = data[0] | (data[1] << 8) | (data[2] << 16)
        sequence_id = data[3]
        command = data[4]

        if command == 0x03:  # COM_QUERY
            query = data[5:5+packet_length-1].decode('utf-8', errors='ignore')
            return query

        elif command == 0x16:  # COM_STMT_PREPARE
            sql = data[5:5+packet_length-1].decode('utf-8', errors='ignore')
            return f"[STMT_PREPARE] {sql}"

        # elif command == 0x17:  # COM_STMT_EXECUTE
        #     header = await src_reader.readexactly(4)
        #     length, seq = struct.unpack('<I', header + b'\x00')[0] & 0xFFFFFF, header[3]
        #     payload = await src_reader.readexactly(length)
            
        #     stmt_id = struct.unpack('<I', payload[1:5])[0]
        #     # params = "[binary parameters omitted]"
        #     # sql = stmt_map.get(stmt_id, "<unknown>")
        #     # print(f"[COM_STMT_EXECUTE] stmt_id={stmt_id} sql={sql} params={params}")
        #     return f"[COM_STMT_EXECUTE] stmt_id={stmt_id}"

        return None

    def inspect_mysql_response(self, data: bytes) -> str:
        """
        Parse MySQL server response packet for OK, ERR, or Result Set.
        """
        if len(data) < 5:
            return None

        header = data[4]
        if header in (0x00, 0xFE):  # OK packet
            return "OK"
        elif header == 0xFF:  # ERR packet
            if len(data) >= 9:
                err_code = data[5] | (data[6] << 8)
                err_msg = data[9:].decode('utf-8', errors='ignore')
                return f"ERROR {err_code}: {err_msg}"
            return "ERROR: Unknown format"
        else:
            return "Result Set"

async def main():
    proxy = MySQLProxy(MYSQL_SERVER_HOST, MYSQL_SERVER_PORT)
    server = await asyncio.start_server(proxy.handle_client, PROXY_HOST, PROXY_PORT)
    addr = server.sockets[0].getsockname()
    print(f"MySQL Proxy running on {addr}")
    async with server:
        await server.serve_forever()

if __name__ == '__main__':
    asyncio.run(main())

