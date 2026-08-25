import asyncio
import contextlib
import os


LISTEN_HOST = os.getenv("LISTEN_HOST", "127.0.0.1")
LISTEN_PORT = int(os.getenv("LISTEN_PORT", "8000"))
UPSTREAM_HOST = os.getenv("UPSTREAM_HOST", "google-workspace-mcp")
UPSTREAM_PORT = int(os.getenv("UPSTREAM_PORT", "8000"))


async def relay(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        while data := await reader.read(64 * 1024):
            writer.write(data)
            await writer.drain()
    except (ConnectionError, asyncio.CancelledError):
        pass


async def handle_connection(
    client_reader: asyncio.StreamReader, client_writer: asyncio.StreamWriter
) -> None:
    try:
        upstream_reader, upstream_writer = await asyncio.open_connection(
            UPSTREAM_HOST, UPSTREAM_PORT
        )
    except OSError as error:
        print(f"Upstream connection failed: {error}")
        client_writer.close()
        await client_writer.wait_closed()
        return

    tasks = {
        asyncio.create_task(relay(client_reader, upstream_writer)),
        asyncio.create_task(relay(upstream_reader, client_writer)),
    }
    _, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)

    for task in pending:
        task.cancel()
    for task in tasks:
        with contextlib.suppress(asyncio.CancelledError):
            await task

    upstream_writer.close()
    client_writer.close()
    with contextlib.suppress(ConnectionError):
        await upstream_writer.wait_closed()
        await client_writer.wait_closed()


async def main() -> None:
    server = await asyncio.start_server(handle_connection, LISTEN_HOST, LISTEN_PORT)
    print(
        f"Loopback proxy listening on {LISTEN_HOST}:{LISTEN_PORT} "
        f"and forwarding to {UPSTREAM_HOST}:{UPSTREAM_PORT}"
    )
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
