import sys
import json
import random

enemy_actions = []
my_actions = []
strategies = []

def track_strategy(name):
    global strategies
    strategies.append(name)

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
    track_strategy('random')
    action = random.choice((0, 1, 2))
    return action

def losing_to_my_last(my_last_action):
    track_strategy('losing_to_my_last')
    action = get_complementary(my_last_action, 'lose')
    return action

def winning_with_my_last(my_last_action):
    track_strategy('winning_with_my_last')
    action = get_complementary(my_last_action, 'win')
    return action

def agent(observation, configuration):
    global enemy_actions
    global my_actions
    if observation.step == 0:
        action = random_agent()
    else:
        enemy_actions.append(observation.lastOpponentAction)
        rand = random.random()
        if rand < 1/3:
            action = winning_with_my_last(my_actions[-1])
        elif rand > 1/3 and rand < 2/3:
            action = losing_to_my_last(my_actions[-1])
        else:
            action = random_agent()
    my_actions.append(action)
    if observation.step == 700:
        sys.stdout.write(json.dumps({
            'enemy_actions': enemy_actions,
            'my_actions': my_actions,
            'strategies': strategies,
        }))
    return action
