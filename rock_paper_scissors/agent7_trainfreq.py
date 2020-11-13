import sys
import json
import random
from collections import Counter

TRAIN_ROUNDS = 200

predicted_responses = {}

enemy_actions = []
my_actions = []
strategies = []

def compute_freq(my_actions, enemy_actions):
    global predicted_responses
    data = {}
    for i, my_action in enumerate(my_actions):
        enemy_action = enemy_actions[i]
        try:
            enemy_next = enemy_actions[i+1]
        except:
            continue
        try:
            data[(my_action, enemy_action)].append(enemy_next)
        except:
            data[(my_action, enemy_action)] = [enemy_next, ]
    for key, val in data.items():
        counts = sorted(Counter(val).items(), key=lambda el: el[1])
        most_common = counts[-1][0]
        predicted_responses[key] = most_common

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

def reactive_agent(predicted_responses, last):
    try:
        action = get_complementary(predicted_responses[last], 'win')
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
    global predicted_responses
    if observation.step > 0:
        enemy_actions.append(observation.lastOpponentAction)
    if observation.step == TRAIN_ROUNDS:
        compute_freq(my_actions, enemy_actions)
    if observation.step <= TRAIN_ROUNDS:
        action = random_agent()
    elif observation.step > TRAIN_ROUNDS:
        action = reactive_agent(predicted_responses, (my_actions[-1], enemy_actions[-1]))
    else:
        # wont happen
        pass
    my_actions.append(action)
    return action
