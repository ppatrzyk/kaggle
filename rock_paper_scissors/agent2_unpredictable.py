import random

enemy_actions = []
my_actions = []

def get_complementary(action, result):
    """
    Get an action that would win/lose with given one

    action - (0, 1, 2)
    result - ('win', 'lose')
    """
    if result == 'win':
        complementary = (action + 1) % 3
    elif result == 'lose':
        complementary = (action + 2) % 3
    else:
        raise ValueError('win/lose expected')
    return complementary

def random_agent():
    action = random.choice((0, 1, 2))
    return action

def losing_to_my_last(my_last_action):
    pass

def agent(observation, configuration):
    global enemy_actions
    global my_actions
    if observation.step == 0:
        return random_agent()
    enemy_actions.append(observation.lastOpponentAction)
    # actions known here
    action = random_agent()
    my_actions.append(action)
    return action
