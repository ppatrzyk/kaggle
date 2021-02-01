import random
import math

def random_agent1():
    action = random.choice((0, 1, 2))
    return action

def random_agent2():
    action = math.ceil(random.uniform(-1, 2))
    return action

def random_agent3():
    max = 100
    num = int(random.uniform(0, max))
    if num > (max/2):
        if not num % 3:
            action = 0
        else:
            action = 1
    else:
        if not num % 3:
            action = 0
        else:
            action = 2
    return action

def agent(observation, configuration):
    rand = random.random()
    action = random.choice([
        random_agent1(),
        random_agent2(),
        random_agent2(),
    ])
