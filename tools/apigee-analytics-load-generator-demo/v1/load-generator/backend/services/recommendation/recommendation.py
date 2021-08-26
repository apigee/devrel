import time
import random

def getRecommendation(id):
    sleepTime = random.randint(1,50)
    print("random sleep: ",sleepTime)
    if id == 1:
        recommendation = {
            "id": "OLJCESPC7Z",
            "name": "Vintage Typewriter",
            "description": "This typewriter looks good in your living room.",
            "picture": "/static/img/products/typewriter.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "67",
                "nanos": 990000000
            },
            "categories": [
                "vintage"
            ]
        }
    elif id == 2:
        recommendation = {
            "id": "OLJCESPC7Z",
            "name": "Vintage Typewriter",
            "description": "This typewriter looks good in your living room.",
            "picture": "/static/img/products/typewriter.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "67",
                "nanos": 990000000
            },
            "categories": [
                "vintage"
            ]
        }
    elif id == 3:
        recommendation = {
            "id": "OLJCESPC7Z",
            "name": "Vintage Typewriter",
            "description": "This typewriter looks good in your living room.",
            "picture": "/static/img/products/typewriter.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "67",
                "nanos": 990000000
            },
            "categories": [
                "vintage"
            ]
        }
    elif id == 4:
        recommendation = {
            "id": "OLJCESPC7Z",
            "name": "Vintage Typewriter",
            "description": "This typewriter looks good in your living room.",
            "picture": "/static/img/products/typewriter.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "67",
                "nanos": 990000000
            },
            "categories": [
                "vintage"
            ]
        }
    elif id == 5:
        recommendation = {
            "id": "OLJCESPC7Z",
            "name": "Vintage Typewriter",
            "description": "This typewriter looks good in your living room.",
            "picture": "/static/img/products/typewriter.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "67",
                "nanos": 990000000
            },
            "categories": [
                "vintage"
            ]
        }
    else:
        return Exception
    if sleepTime == id:
        print("sleeping")
        time.sleep (random.randint(0,7))
    return recommendation