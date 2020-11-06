import random

# Data:
# observation.step
# observation.lastOpponentAction

# rock 0
# paper 1
# scissors 2

def random_agent(observation, configuration):
    action = random.choice((0, 1, 2))
    return action

def agent(observation, configuration):
    current_agent = random_agent
    return current_agent(observation, configuration)
