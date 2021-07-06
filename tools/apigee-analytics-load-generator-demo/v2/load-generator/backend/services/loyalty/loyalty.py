import time
import random

def getTotalLoyaltyPoints(id):
    sleepTime = random.randint(1,50)
    print("random sleep: ",sleepTime)
    if id == 1:
        points = {
            "total_rewards_points":43526244,
            "healthy_choice_points":665446,
            "transaction_id":"234099-324234-4324532"
        }
    elif id == 2:
        points = {
            "total_rewards_points":53465,
            "healthy_choice_points":665,
            "transaction_id":"234099-324234-4324532"
        }
    elif id == 3:
        points = {
            "total_rewards_points":4356,
            "healthy_choice_points":54,
            "transaction_id":"234099-324234-4324532"
        }
    elif id == 4:
        points = {
            "total_rewards_points":788769,
            "healthy_choice_points":23,
            "transaction_id":"234099-324234-4324532"
        }
    elif id == 5:
        points = {
            "total_rewards_points":8987087,
            "healthy_choice_points":543,
            "transaction_id":"234099-324234-4324532"
        }
    else:
        return False
    if sleepTime == id:
        print("sleeping")
        time.sleep (random.randint(0,7))
    return points