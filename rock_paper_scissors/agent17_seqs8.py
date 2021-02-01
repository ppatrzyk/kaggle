import sys
import json
import random
from collections import Counter

RANDOM_PROP = 0.05
MEMORY = 200
TOP_FREQ = 0.75

enemy_actions = []
my_actions = []
strategies = []

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

def track_strategy(name):
    global strategies
    sys.stdout.write(str(name))
    strategies.append(name)

def reactive_agent(my_actions, enemy_actions):
    assert len(my_actions) == len(enemy_actions), 'action tracking error'
    try:
        my_previous = my_actions[-1]
        reactions = list(zip(
            my_actions[:-1],
            enemy_actions[1:]
        ))
        reactions = reactions[-MEMORY:]
        counter = Counter(reactions)
        counter = {key[1]: val for (key, val) in counter.items() if key[0] == my_previous}
        sys.stdout.write(f'Resp to {my_previous}: {str(counter)}')
        counter = {key: val/sum(counter.values()) for key, val in counter.items()}
        counter = sorted(counter.items(), key=lambda el: el[1], reverse=True)
        assert counter[0][1] >= TOP_FREQ, 'random enemy action'
        enemy_action = counter[0][0]
        action = get_complementary(enemy_action, 'win')
        track_strategy('reactive')
    except:
        action = random.choice((0, 1, 2))
        track_strategy('reactive-fallback-random')
    return action

def random_agent():
    track_strategy('random')
    action = random.choice((0, 1, 2))
    return action

def agent(observation, configuration):
    global enemy_actions
    global my_actions
    rand = random.random()
    if observation.step > 0:
        enemy_actions.append(observation.lastOpponentAction)
    if observation.step == 0 or rand < RANDOM_PROP:
        action = random_agent()
    else:
        action = reactive_agent(my_actions, enemy_actions)
    my_actions.append(action)
    return action
