"""CONNECT proxy for the domestic-only release test network."""

import asyncio


MIRRORS = (
    "gitee.com",
    "giteeusercontent.com",
    "mirrors.ustc.edu.cn",
    "mirrors.tuna.tsinghua.edu.cn",
    "npmmirror.com",
)


async def relay(source, target):
    while chunk := await source.read(65536):
        target.write(chunk)
        await target.drain()


async def proxy(client, client_writer):
    remote_writer = None
    directions = []
    try:
        method, authority, _ = (await client.readline()).decode("ascii").split()
        host, port = authority.lower().rsplit(":", 1)
        if method != "CONNECT" or port != "443" or not any(
            host == mirror or host.endswith("." + mirror) for mirror in MIRRORS
        ):
            print(f"DENIED {method} {authority}", flush=True)
            client_writer.write(b"HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n")
            await client_writer.drain()
            return
        while await client.readline() not in (b"\r\n", b""):
            pass
        remote, remote_writer = await asyncio.wait_for(
            asyncio.open_connection(host, 443), timeout=20
        )
        client_writer.write(b"HTTP/1.1 200 Connection established\r\n\r\n")
        await client_writer.drain()
        directions = [
            asyncio.create_task(relay(client, remote_writer)),
            asyncio.create_task(relay(remote, client_writer)),
        ]
        await asyncio.wait(directions, return_when=asyncio.FIRST_COMPLETED)
    except (ValueError, OSError, asyncio.TimeoutError):
        pass
    finally:
        for direction in directions:
            direction.cancel()
        if directions:
            await asyncio.gather(*directions, return_exceptions=True)
        if remote_writer:
            remote_writer.close()
        client_writer.close()


async def main():
    async with await asyncio.start_server(proxy, "0.0.0.0", 8080) as server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
