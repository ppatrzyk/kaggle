import random

# Data:
# observation.step
# observation.lastOpponentAction

# rock 0
# paper 1
# scissors 2

enemy_actions = []
my_actions = []

def random_agent():
    action = random.choice((0, 1, 2))
    return action

def agent(observation, configuration):
    global enemy_actions
    global my_actions
    if observation.step == 0:
        return random_agent()
    enemy_actions.append(observation.lastOpponentAction)
    # actions knows here
    action = random_agent()
    my_actions.append(action)
    return action
