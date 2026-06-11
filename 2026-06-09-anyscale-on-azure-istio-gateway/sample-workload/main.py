import ray
import time

num_ray_tasks = 5

@ray.remote
def process(x):
    if x == (num_ray_tasks - 1):
        print("Hello from one of the Running Ray Tasks!")
        time.sleep(200)
    return x * 2

result = ray.get([process.remote(x) for x in range(num_ray_tasks)])
print("The job result is", result)