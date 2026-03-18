import ray
import time
import socket

ray.init()

@ray.remote
def ping():
    return f"Pong from {socket.gethostname()}"

# Wait for 2 nodes
print("Waiting for nodes...")
timeout = 30
start = time.time()
while time.time() - start < timeout:
    if len(ray.nodes()) >= 2:
        break
    time.sleep(1)

print(f"Nodes found: {len(ray.nodes())}")
refs = [ping.remote() for _ in range(4)]
print(ray.get(refs))
