import asyncio
import logging
from datetime import datetime
import os
from zoneinfo import ZoneInfo
import struct

# Configuration
MYSQL_SERVER_HOST = 'db'
MYSQL_SERVER_PORT = 3306
PROXY_HOST = '127.0.0.1'
PROXY_PORT = 3306
WUT_NAME = os.environ.get('WUT_NAME', "")
FOLDER_NAME = os.environ.get('FOLDER_NAME', "/shared-data")
LOG_FILE = f'{FOLDER_NAME}/mysql_proxy_{WUT_NAME}.log'

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

logging.basicConfig(level=logging.INFO, handlers=[handler])

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

class MySQLProxy:
    def __init__(self, mysql_host, mysql_port):
        self.mysql_host = mysql_host
        self.mysql_port = mysql_port
        self.query_info = {}

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
                    data = await reader.read(4096)
                    if not data:
                        break

                    # Intercept client->server packets for SQL
                    if direction == "client->server":
                        recv_time = datetime.now()
                        try:
                            # LOCAL_TZ = ZoneInfo("Europe/Amsterdam")  # replace with your timezone
                            # recv_time = datetime.now(LOCAL_TZ)
                            query = self.extract_sql_query(reader, data)
                            if query:
                                # log_query(recv_time, query, addr)
                                self.query_info[addr] = {
                                    "query": query,
                                    "start_time": recv_time
                                }
                        except Exception as e:
                            log_error(recv_time, f"Malformed packet or unknown structure: {e}", addr)

                    elif direction == "server->client":
                        # Check if we have a pending query for this client
                        if addr in self.query_info:
                            result_str = self.inspect_mysql_response(data)
                            qinfo = self.query_info.pop(addr)
                            
                            # if result_str:
                            #     logging.info(
                            #         f"[{addr}] Query: {qinfo['query']}\n"
                            #         f"    Result: {result_str}\n"
                            #     )
                            
                            log_query(qinfo['start_time'], f"{qinfo['query']} **{result_str}", addr)

                    writer.write(data)
                    await writer.drain()
            except Exception as e:
                logging.error(f"Relay error [{direction}]: {e}")
            finally:
                writer.close()

        # Launch bidirectional relays
        await asyncio.gather(
            relay(client_reader, server_writer, "client->server"),
            relay(server_reader, client_writer, "server->client"),
        )

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

