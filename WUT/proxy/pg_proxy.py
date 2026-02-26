#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Postgres transparent TCP proxy that logs:
  • Simple Query protocol (Q)
  • Extended Query protocol (Parse P / Bind B / Execute E / Close C / Sync S)
  • Reconstructs SQL by substituting $1..$N with bound values when possible

IMPORTANT LIMITATION:
  This proxy can only parse traffic that is NOT encrypted with TLS.
  If the client negotiates SSL/TLS with the server (SSLRequest -> 'S'),
  the stream becomes opaque and cannot be parsed without a MITM cert setup.
  For development, set PGSSLMODE=disable (or sslmode=disable in the DSN)
  so the server replies 'N' and traffic stays in cleartext.

Tested against PostgreSQL 13–16 in local (non-SSL) mode.

Usage:
  python postgres_proxy.py --listen 127.0.0.1:55432 --target 127.0.0.1:5432

Then point your app/psql to 127.0.0.1:55432 with sslmode=disable.
"""
import asyncio
import logging
import argparse
import os
from typing import Dict, Tuple, List, Optional
from collections import deque

DB_CONTAINER_NAME = os.environ.get('DB_CONTAINER_NAME', "db")
WUT_NAME = os.environ.get('WUT_NAME', "")
HOST_NAME = os.environ.get('HOST_NAME', "")
FOLDER_NAME = os.environ.get('FOLDER_NAME', "/shared-data")
LOG_FILE = f'{FOLDER_NAME}/mysql_proxy_{WUT_NAME}{HOST_NAME}.log'

# ---------- Logging setup ----------
LOG = logging.getLogger("pgproxy")
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

# ---------- Helpers ----------

def pg_escape(v: Optional[str]) -> str:
    """Very simple text escaping for logging purposes only.
    If value looks numeric, keep as-is; else single-quote and escape quotes/backslashes.
    """
    if v is None:
        return "NULL"
    # Try numeric
    try:
        float(v)
        # keep numeric as-is
        return v
    except Exception:
        pass
    # Quote strings
    s = v.replace("\\", "\\\\").replace("'", "''")
    return f"'{s}'"


def substitute_params(sql: str, params: List[Optional[str]]) -> str:
    """Substitute $1..$N with logged param values (textual best-effort).
    We only replace exact $N tokens to avoid touching other substrings.
    """
    out = sql
    for i, raw in enumerate(params, start=1):
        token = f"${i}"
        val = pg_escape(raw)
        out = out.replace(token, val)
    return out

# ---------- Protocol parsing ----------
class PGSession:
    """Holds per-connection state to reconstruct Extended Query executions."""
    def __init__(self) -> None:
        self.statements: Dict[str, Tuple[str, List[int]]] = {}
        self.portals: Dict[str, str] = {}
        # whether this stream has turned TLS (opaque); if True, stop parsing
        self.tls_active: bool = False
        # for initial StartupMessage tracking
        self.seen_startup: bool = False
        
        # FIFO queues to track pending operations (responses don't include stmt/portal names)
        # Queue of (stmt_name, query_string) for Parse -> ParseComplete
        self.pending_parses: deque = deque()
        # Queue of (portal_name, query_string) for Bind -> BindComplete
        self.pending_binds: deque = deque()
        # Queue of (portal_name, query_string) for Execute -> CommandComplete
        self.pending_executes: deque = deque()
        # Simple Query (no name) tracked by addr
        self.simple_queries: Dict[Tuple, str] = {}

    # ---- Client -> Server messages ----
    def parse_client_message(self, mtype: Optional[bytes], payload: bytes, addr) -> None:
        """Parse a single client message. mtype=None means Startup/SSLRequest (no type byte)."""
        if self.tls_active:
            return
        if mtype is None:
            # Could be SSLRequest or StartupMessage; we only inspect the 4-byte protocol/ssl code at start
            if len(payload) >= 4:
                code = int.from_bytes(payload[:4], "big")
                if code == 80877103:  # SSLRequest magic
                    pass
                else:
                    self.seen_startup = True
            return

        t = mtype
        if t == b"Q":  # Simple Query
            # payload: query\x00
            query = payload[:-1].decode(errors="replace") if payload and payload.endswith(b"\x00") else payload.decode(errors="replace")
            sql_oneline = ' '.join(query.split())

            LOG.info(f"[{addr}] ### {sql_oneline} *#*#Query")
            self.simple_queries[addr] = f"### {sql_oneline}"
            ## We should wait for the response from **CommandComplete
        elif t == b"P":  # Parse
            # statement name\x00, query\x00, int16 nparams, int32[nparams] type OIDs
            pos = 0
            name_end = payload.find(b"\x00", pos)
            stmt_name = payload[pos:name_end].decode(errors="replace")
            pos = name_end + 1
            q_end = payload.find(b"\x00", pos)
            sql = payload[pos:q_end].decode(errors="replace")
            pos = q_end + 1
            if pos + 2 > len(payload):
                nparams = 0
                oids: List[int] = []
            else:
                nparams = int.from_bytes(payload[pos:pos+2], "big")
                pos += 2
                oids = []
                for _ in range(nparams):
                    if pos + 4 > len(payload):
                        break
                    oids.append(int.from_bytes(payload[pos:pos+4], "big"))
                    pos += 4
            self.statements[stmt_name] = (sql, oids)
            # Normalize SQL: replace newlines and multiple spaces with single space
            sql_oneline = ' '.join(sql.split())
            # Log Parse immediately AND push to pending queue
            stmt_key = stmt_name or '<unnamed>'
            LOG.info(f"[{addr}] ### {sql_oneline} *#*#Parse[{stmt_key}]")
            self.pending_parses.append((stmt_key, f"### {sql_oneline}"))
            ## We should wait for the response from **ParseComplete
        elif t == b"B":  # Bind
            # portal\x00, statement\x00, int16 nFormatCodes, int16[] fmts,
            # int16 nparams, for each: int32 len (-1 null), bytes,
            # int16 nResultFormatCodes, int16[]
            pos = 0
            por_end = payload.find(b"\x00", pos)
            portal = payload[pos:por_end].decode(errors="replace")
            pos = por_end + 1
            st_end = payload.find(b"\x00", pos)
            stmt = payload[pos:st_end].decode(errors="replace")
            pos = st_end + 1

            # parameter format codes
            if pos + 2 > len(payload):
                return
            nfmts = int.from_bytes(payload[pos:pos+2], "big"); pos += 2
            fmts: List[int] = []
            for _ in range(nfmts):
                if pos + 2 > len(payload):
                    break
                fmts.append(int.from_bytes(payload[pos:pos+2], "big")); pos += 2

            if pos + 2 > len(payload):
                return
            nparams = int.from_bytes(payload[pos:pos+2], "big"); pos += 2
            vals: List[Optional[str]] = []
            for _ in range(nparams):
                if pos + 4 > len(payload):
                    break
                l = int.from_bytes(payload[pos:pos+4], "big"); pos += 4
                if l == 0xFFFFFFFF:  # -1 NULL
                    vals.append(None)
                else:
                    if pos + l > len(payload):
                        raw = payload[pos:]
                        pos = len(payload)
                    else:
                        raw = payload[pos:pos+l]
                        pos += l
                    # Determine format (0=text, 1=binary). If one format code supplied, applies to all.
                    fmt = fmts[0] if len(fmts) == 1 else (fmts[len(vals)] if len(fmts) == nparams else 0)
                    if fmt == 0:
                        try:
                            vals.append(raw.decode())
                        except Exception:
                            vals.append(raw.decode(errors="replace"))
                    else:
                        # binary – log hex snippet
                        vals.append("\\x" + raw.hex())

            # map the portal to the statement
            self.portals[portal] = stmt

            # Try to reconstruct SQL now (even though execution might happen later)
            sql, _oids = self.statements.get(stmt, ("<unknown>", []))
            filled = substitute_params(sql, vals)
            portal_key = portal or '<unnamed>'
            stmt_key = stmt or '<unnamed>'
            LOG.info(f"[{addr}] ### {vals} *#*#Bind[stmt={stmt_key},portal={portal_key}]")
            self.pending_binds.append((portal_key, f"### {vals}"))
            ## We should wait for the response from **BindComplete
        elif t == b"E":  # Execute
            # portal\x00, int32 max-rows
            pos = 0
            end = payload.find(b"\x00", pos)
            portal = payload[pos:end].decode(errors="replace")
            pos = end + 1
            max_rows = int.from_bytes(payload[pos:pos+4], "big") if pos + 4 <= len(payload) else 0
            stmt = self.portals.get(portal, '')
            sql, _ = self.statements.get(stmt, ("<unknown>", []))
            portal_key = portal or '<unnamed>'
            stmt_key = stmt or '<unnamed>'
            # Find the query from the most recent Bind for this portal
            bound_query = f"### executedstmt='{stmt_key}'"
            for p_name, p_query in reversed(self.pending_binds):
                if p_name == portal_key:
                    bound_query = p_query
                    break
            self.pending_executes.append((portal_key, bound_query))
            ## We should wait for the response from **CommandComplete
        elif t == b"C":  # Close
            # kind('S' or 'P'), name\x00
            kind = chr(payload[0]) if payload else '?'
            name = payload[1:payload.find(b"\x00", 1)].decode(errors="replace") if len(payload) > 1 else ''
            if kind == 'S':
                self.statements.pop(name, None)
            elif kind == 'P':
                self.portals.pop(name, None)
        elif t == b"S":  # Sync
            pass
        elif t == b"D":  # Describe
            pass
        else:
            # Other front-end types: F (FunctionCall), X (Terminate), etc.
            try:
                ch = t.decode()
            except Exception:
                ch = str(t)
            LOG.debug(f"[{addr}] ### Unhandledtype %s", ch)

    # ---- Server -> Client messages ----
    def parse_server_message(self, mtype: Optional[bytes], payload: bytes, addr) -> None:
        if self.tls_active:
            return
        if mtype is None:
            # Server SSL response is a single byte 'S' or 'N' WITHOUT length header.
            # BUT since we're using framed reads, we shouldn't see it here.
            return
        t = mtype
        if t == b"N":  # NoticeResponse
            pass
        elif t == b"E":  # ErrorResponse
            # # payload is sequence of fields code + cstring; ends with 0x00

            error_fields = {}
            i = 0
            while i < len(payload):
                field_type = payload[i:i+1]
                i += 1
                if field_type == b'\x00':
                    break
                end = payload.find(b'\x00', i)
                if end == -1:
                    break  # Malformed packet
                value = payload[i:end].decode('utf-8', errors='replace')
                error_fields[field_type] = value
                i = end + 1

            severity = error_fields.get(b'S', 'UNKNOWN')
            code = error_fields.get(b'C', '?????')
            message = error_fields.get(b'M', '[no message]')
            message_oneline = ' '.join(message.split())
            
            # Error can occur during Parse, Bind, or Execute - check all pending queues
            query = '[unknown query]'
            context = ''
            if self.pending_parses:
                stmt_name, query = self.pending_parses.popleft()
                context = f'Parse[{stmt_name}]'
            elif self.pending_binds:
                portal_name, query = self.pending_binds.popleft()
                context = f'Bind[{portal_name}]'
            elif self.pending_executes:
                portal_name, query = self.pending_executes.popleft()
                context = f'Execute[{portal_name}]'
            elif addr in self.simple_queries:
                query = self.simple_queries.pop(addr)
                context = 'SimpleQuery'
            
            LOG.warning(
                f"[{addr}] {query} *#*#error[{context}] Severity={severity} Code={code} Message={message_oneline}"
            )

        elif t == b"R":  # Authentication
            if len(payload) >= 4:
                atype = int.from_bytes(payload[:4], "big")
        elif t == b"S":  # ParameterStatus
            # key\x00 value\x00
            pass
        elif t == b"K":  # BackendKeyData
            pass
        elif t == b"Z":  # ReadyForQuery
            # status byte
            status = chr(payload[0]) if payload else '?'
        elif t == b"1":  # ParseComplete
            if self.pending_parses:
                stmt_name, query = self.pending_parses.popleft()
                LOG.info(f"[{addr}] {query} *#*#ParseComplete[{stmt_name}]")
            else:
                LOG.info(f"[{addr}] ### [unknown] *#*#ParseComplete")
        elif t == b"2":  # BindComplete
            if self.pending_binds:
                portal_name, query = self.pending_binds.popleft()
                LOG.info(f"[{addr}] {query} *#*#BindComplete[{portal_name}]")
            else:
                LOG.info(f"[{addr}] ### [unknown] *#*#BindComplete")
        elif t == b"3":  # CloseComplete
            pass
        elif t == b"t":  # ParameterDescription
            # int16 nparams, for each: int32 oid
            pass
        elif t == b"T":  # RowDescription (columns)
            pass
        elif t == b"D":  # DataRow
            pass
        elif t == b"C":  # CommandComplete
            # e.g., "SELECT 1\x00"
            try:
                tag = payload[:-1].decode()
            except Exception:
                tag = payload.decode(errors="replace")
            # Check if this is from Extended Query (Execute) or Simple Query
            if self.pending_executes:
                portal_name, query = self.pending_executes.popleft()
                LOG.info(f"[{addr}] {query} *#*#CommandComplete[{portal_name}]")
            elif addr in self.simple_queries:
                query = self.simple_queries.pop(addr)
                LOG.info(f"[{addr}] {query} *#*#CommandComplete[SimpleQuery]")
            else:
                LOG.info(f"[{addr}] ### [unknown] *#*#CommandComplete")
        else:
            try:
                ch = t.decode()
            except Exception:
                ch = str(t)
            LOG.debug(f"[{addr}] ### Unhandledtype %s", ch)


# ---------- Framing / Relay ----------
async def read_message(reader: asyncio.StreamReader, *, client_side: bool, session: PGSession) -> Tuple[Optional[bytes], bytes]:
    """Read a single PostgreSQL message.
    Returns (type_byte_or_None, payload_bytes).
    Special cases:
      • StartupMessage and SSLRequest (client->server) have NO type byte; first 4 bytes are length.
      • SSLResponse from server is a single byte 'S' or 'N' (but that happens outside framed reads).
    """
    # For client before startup: message has no type byte
    if client_side and not session.seen_startup:
        # read length (int32), then payload of that length-4
        hdr = await reader.readexactly(4)
        length = int.from_bytes(hdr, "big")
        payload = await reader.readexactly(length - 4)
        return None, payload

    # Normal framed: 1-byte type + int32 length + payload(length-4)
    mtype = await reader.readexactly(1)

    # Handle server's one-byte SSL response specially (before any normal framing)
    if not client_side and not session.seen_startup and (mtype in (b"S", b"N")):
        # Mark TLS if 'S'
        if mtype == b"S":
            session.tls_active = True
        # After SSL response, the client will either switch to TLS (opaque) or send Startup again.
        return mtype, b""

    length_bytes = await reader.readexactly(4)
    length = int.from_bytes(length_bytes, "big")
    payload = await reader.readexactly(length - 4)
    return mtype, payload


async def relay_pair(client_reader: asyncio.StreamReader, client_writer: asyncio.StreamWriter,
                     target_host: str, target_port: int):
    server_reader, server_writer = await asyncio.open_connection(target_host, target_port)
    session = PGSession()
    addr = client_writer.get_extra_info('peername')

    async def c2s():
        try:
            while True:
                mtype, payload = await read_message(client_reader, client_side=True, session=session)
                # Parse & forward
                session.parse_client_message(mtype, payload, addr)
                # Reframe and forward
                if mtype is None:
                    # Startup or SSLRequest: frame is length + payload only
                    length = (4 + len(payload)).to_bytes(4, "big")
                    server_writer.write(length + payload)
                else:
                    server_writer.write(mtype + (4 + len(payload)).to_bytes(4, "big") + payload)
                await server_writer.drain()
        except asyncio.IncompleteReadError:
            pass
        except Exception as e:
            print("Relay error [client->server]: %s", e)
        finally:
            try:
                server_writer.close(); await server_writer.wait_closed()
            except Exception:
                pass

    async def s2c():
        try:
            while True:
                mtype, payload = await read_message(server_reader, client_side=False, session=session)
                session.parse_server_message(mtype, payload, addr)
                # Forward
                if mtype in (b"S", b"N") and not session.seen_startup:
                    # one-byte SSL response, no length
                    client_writer.write(mtype)
                elif mtype is None:
                    # Shouldn't happen server-side in normal flow
                    client_writer.write((4 + len(payload)).to_bytes(4, "big") + payload)
                else:
                    client_writer.write(mtype + (4 + len(payload)).to_bytes(4, "big") + payload)
                await client_writer.drain()
                # After ReadyForQuery we know startup completed
                if mtype == b"Z":
                    session.seen_startup = True
        except asyncio.IncompleteReadError:
            pass
        except Exception as e:
            print("Relay error [server->client]: %s", e)
        finally:
            try:
                client_writer.close(); await client_writer.wait_closed()
            except Exception:
                pass

    await asyncio.gather(c2s(), s2c())


async def main():
    ap = argparse.ArgumentParser(description="Postgres proxy with query logging")
    ap.add_argument("--listen", default="0.0.0.0:5432", help="host:port to listen on")
    ap.add_argument("--target", default=f"{DB_CONTAINER_NAME}:5432", help="Postgres server host:port")
    args = ap.parse_args()

    lhost, lport = args.listen.split(":"); lport = int(lport)
    thost, tport = args.target.split(":"); tport = int(tport)

    server = await asyncio.start_server(lambda r, w: relay_pair(r, w, thost, tport), lhost, lport)
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
