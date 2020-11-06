import random

# Data:
# observation.step
# observation.lastOpponentAction

# rock 0
# paper 1
# scissors 2

enemy_actions = []
my_actions = []

def random_agent(observation, configuration):
    action = random.choice((0, 1, 2))
    return action

def agent(observation, configuration):
    global enemy_actions
    global my_actions
    if observation.step == 0:
        return random_agent(observation, configuration)
    enemy_actions.append(observation.lastOpponentAction)
    current_agent = random_agent
    action = current_agent(observation, configuration)
    my_actions.append(action)
    return action
