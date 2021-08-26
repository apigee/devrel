import random
import requests
import os
import json
from locust import HttpLocust, TaskSet



token = os.getenv("TOKEN")
apigee_org = os.getenv("APIGEE_ORG")
apigee_url="https://apigee.googleapis.com/v1/organizations/"+apigee_org+"/"
apigee_env = os.getenv("APIGEE_ENV")

hugePayload = {"Content":"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed et tortor elit. Vivamus nibh orci, auctor eu pharetra sit amet, finibus et turpis. Nullam scelerisque vel lorem et condimentum. Pellentesque a est nulla. Praesent molestie cursus commodo. Integer ac odio at arcu imperdiet volutpat ut et velit. Ut viverra pellentesque elit eget mattis. Maecenas et convallis risus. Aenean sem nisl, cursus sit amet faucibus eget, lacinia eget sapien. Aenean eu elementum mi, condimentum pharetra ante. Aliquam scelerisque malesuada purus.Etiam elementum libero neque, id pellentesque lectus sodales non. Suspendisse dui arcu, vehicula quis diam semper, tempus elementum nulla. Duis ut ipsum ut ex mollis malesuada sed ultrices nisl. Etiam sit amet massa vestibulum, imperdiet nunc ac, sagittis massa. Nulla quis orci sit amet sem faucibus malesuada. Sed ut eros placerat, consequat nisl facilisis, accumsan diam. Phasellus eleifend velit non iaculis aliquet. Etiam ac dolor tincidunt, luctus metus et, luctus erat. Praesent fermentum sed dui et fermentum. Donec nec pretium neque, eu vulputate urna. Donec non metus sit amet velit interdum viverra. Praesent non luctus velit. Maecenas velit arcu, suscipit sed mauris et, ultrices ullamcorper arcu. Phasellus commodo magna metus, vel mollis arcu aliquam non. Nunc rhoncus velit nisi, a fermentum eros luctus nec.Cras cursus tempus velit, vel commodo ex dapibus a. Sed nec commodo libero, semper iaculis purus. Praesent faucibus, mi vitae scelerisque feugiat, ligula dui dictum quam, eget porta neque quam ac ligula. Ut ullamcorper ipsum quis urna ornare, vitae consequat nibh viverra. Curabitur semper feugiat nunc et ultrices. Suspendisse id tellus in velit auctor elementum vitae in enim. Nunc eu venenatis risus. Sed sed purus magna. Proin nec facilisis eros. Donec et elit id risus tristique congue ut nec lectus. Sed augue mi, accumsan non ligula vel, dapibus lacinia mauris. Mauris quam arcu, congue et sapien eu, consectetur placerat nisl. Nam finibus quam pulvinar vehicula placerat.Quisque rhoncus sapien quis turpis lacinia, egestas congue neque placerat. Phasellus eu bibendum quam. Proin quis justo erat. Nam faucibus lorem iaculis, aliquam risus non, vulputate sapien. Ut gravida interdum mauris vel rutrum. Nullam tortor est, bibendum at nibh quis, tincidunt rutrum tellus. Integer luctus ante eu sapien euismod, a tempus quam congue. Donec ullamcorper posuere leo, vel condimentum purus venenatis ut. Maecenas in faucibus justo, convallis euismod sem. In ut magna vel est blandit porta. Ut et porta lorem, et scelerisque tortor. Curabitur faucibus, velit vel tristique aliquam, leo nibh porta sem, at euismod augue tortor a sapien. Maecenas sit amet augue id ipsum dictum malesuada id ac ligula. Fusce vel fringilla nisl, nec hendrerit sapien.Vestibulum lorem nisl, cursus varius lacus quis, eleifend posuere sem. Cras vehicula faucibus diam a vehicula. Etiam tincidunt malesuada porta. Aliquam erat volutpat. Integer nec diam diam. Nullam tortor lorem, rutrum nec consectetur vitae, gravida a purus. Nullam vehicula eros libero, non consectetur ligula imperdiet nec. Quisque malesuada justo mi, at tincidunt neque pharetra et. Duis vitae magna eu libero malesuada dictum. Maecenas sit amet ornare velit. Maecenas egestas velit egestas felis dignissim blandit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed et tortor elit. Vivamus nibh orci, auctor eu pharetra sit amet, finibus et turpis. Nullam scelerisque vel lorem et condimentum. Pellentesque a est nulla. Praesent molestie cursus commodo. Integer ac odio at arcu imperdiet volutpat ut et velit. Ut viverra pellentesque elit eget mattis. Maecenas et convallis risus. Aenean sem nisl, cursus sit amet faucibus eget, lacinia eget sapien. Aenean eu elementum mi, condimentum pharetra ante. Aliquam scelerisque malesuada purus.Etiam elementum libero neque, id pellentesque lectus sodales non. Suspendisse dui arcu, vehicula quis diam semper, tempus elementum nulla. Duis ut ipsum ut ex mollis malesuada sed ultrices nisl. Etiam sit amet massa vestibulum, imperdiet nunc ac, sagittis massa. Nulla quis orci sit amet sem faucibus malesuada. Sed ut eros placerat, consequat nisl facilisis, accumsan diam. Phasellus eleifend velit non iaculis aliquet. Etiam ac dolor tincidunt, luctus metus et, luctus erat. Praesent fermentum sed dui et fermentum. Donec nec pretium neque, eu vulputate urna. Donec non metus sit amet velit interdum viverra. Praesent non luctus velit. Maecenas velit arcu, suscipit sed mauris et, ultrices ullamcorper arcu. Phasellus commodo magna metus, vel mollis arcu aliquam non. Nunc rhoncus velit nisi, a fermentum eros luctus nec.Cras cursus tempus velit, vel commodo ex dapibus a. Sed nec commodo libero, semper iaculis purus. Praesent faucibus, mi vitae scelerisque feugiat, ligula dui dictum quam, eget porta neque quam ac ligula. Ut ullamcorper ipsum quis urna ornare, vitae consequat nibh viverra. Curabitur semper feugiat nunc et ultrices. Suspendisse id tellus in velit auctor elementum vitae in enim. Nunc eu venenatis risus. Sed sed purus magna. Proin nec facilisis eros. Donec et elit id risus tristique congue ut nec lectus. Sed augue mi, accumsan non ligula vel, dapibus lacinia mauris. Mauris quam arcu, congue et sapien eu, consectetur placerat nisl. Nam finibus quam pulvinar vehicula placerat.Quisque rhoncus sapien quis turpis lacinia, egestas congue neque placerat. Phasellus eu bibendum quam. Proin quis justo erat. Nam faucibus lorem iaculis, aliquam risus non, vulputate sapien. Ut gravida interdum mauris vel rutrum. Nullam tortor est, bibendum at nibh quis, tincidunt rutrum tellus. Integer luctus ante eu sapien euismod, a tempus quam congue. Donec ullamcorper posuere leo, vel condimentum purus venenatis ut. Maecenas in faucibus justo, convallis euismod sem. In ut magna vel est blandit porta. Ut et porta lorem, et scelerisque tortor. Curabitur faucibus, velit vel tristique aliquam, leo nibh porta sem, at euismod augue tortor a sapien. Maecenas sit amet augue id ipsum dictum malesuada id ac ligula. Fusce vel fringilla nisl, nec hendrerit sapien.Vestibulum lorem nisl, cursus varius lacus quis, eleifend posuere sem. Cras vehicula faucibus diam a vehicula. Etiam tincidunt malesuada porta. Aliquam erat volutpat. Integer nec diam diam. Nullam tortor lorem, rutrum nec consectetur vitae, gravida a purus. Nullam vehicula eros libero, non consectetur ligula imperdiet nec. Quisque malesuada justo mi, at tincidunt neque pharetra et. Duis vitae magna eu libero malesuada dictum. Maecenas sit amet ornare velit. Maecenas egestas velit egestas felis dignissim blandit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed et tortor elit. Vivamus nibh orci, auctor eu pharetra sit amet, finibus et turpis. Nullam scelerisque vel lorem et condimentum. Pellentesque a est nulla. Praesent molestie cursus commodo. Integer ac odio at arcu imperdiet volutpat ut et velit. Ut viverra pellentesque elit eget mattis. Maecenas et convallis risus. Aenean sem nisl, cursus sit amet faucibus eget, lacinia eget sapien. Aenean eu elementum mi, condimentum pharetra ante. Aliquam scelerisque malesuada purus.Etiam elementum libero neque, id pellentesque lectus sodales non. Suspendisse dui arcu, vehicula quis diam semper, tempus elementum nulla. Duis ut ipsum ut ex mollis malesuada sed ultrices nisl. Etiam sit amet massa vestibulum, imperdiet nunc ac, sagittis massa. Nulla quis orci sit amet sem faucibus malesuada. Sed ut eros placerat, consequat nisl facilisis, accumsan diam. Phasellus eleifend velit non iaculis aliquet. Etiam ac dolor tincidunt, luctus metus et, luctus erat. Praesent fermentum sed dui et fermentum. Donec nec pretium neque, eu vulputate urna. Donec non metus sit amet velit interdum viverra. Praesent non luctus velit. Maecenas velit arcu, suscipit sed mauris et, ultrices ullamcorper arcu. Phasellus commodo magna metus, vel mollis arcu aliquam non. Nunc rhoncus velit nisi, a fermentum eros luctus nec.Cras cursus tempus velit, vel commodo ex dapibus a. Sed nec commodo libero, semper iaculis purus. Praesent faucibus, mi vitae scelerisque feugiat, ligula dui dictum quam, eget porta neque quam ac ligula. Ut ullamcorper ipsum quis urna ornare, vitae consequat nibh viverra. Curabitur semper feugiat nunc et ultrices. Suspendisse id tellus in velit auctor elementum vitae in enim. Nunc eu venenatis risus. Sed sed purus magna. Proin nec facilisis eros. Donec et elit id risus tristique congue ut nec lectus. Sed augue mi, accumsan non ligula vel, dapibus lacinia mauris. Mauris quam arcu, congue et sapien eu, consectetur placerat nisl. Nam finibus quam pulvinar vehicula placerat.Quisque rhoncus sapien quis turpis lacinia, egestas congue neque placerat. Phasellus eu bibendum quam. Proin quis justo erat. Nam faucibus lorem iaculis, aliquam risus non, vulputate sapien. Ut gravida interdum mauris vel rutrum. Nullam tortor est, bibendum at nibh quis, tincidunt rutrum tellus. Integer luctus ante eu sapien euismod, a tempus quam congue. Donec ullamcorper posuere leo, vel condimentum purus venenatis ut. Maecenas in faucibus justo, convallis euismod sem. In ut magna vel est blandit porta. Ut et porta lorem, et scelerisque tortor. Curabitur faucibus, velit vel tristique aliquam, leo nibh porta sem, at euismod augue tortor a sapien. Maecenas sit amet augue id ipsum dictum malesuada id ac ligula. Fusce vel fringilla nisl, nec hendrerit sapien.Vestibulum lorem nisl, cursus varius lacus quis, eleifend posuere sem. Cras vehicula faucibus diam a vehicula. Etiam tincidunt malesuada porta. Aliquam erat volutpat. Integer nec diam diam. Nullam tortor lorem, rutrum nec consectetur vitae, gravida a purus. Nullam vehicula eros libero, non consectetur ligula imperdiet nec. Quisque malesuada justo mi, at tincidunt neque pharetra et. Duis vitae magna eu libero malesuada dictum. Maecenas sit amet ornare velit. Maecenas egestas velit egestas felis dignissim blandit."}

#User Agents
userAgent1 = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36'
userAgent2 = 'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Mobile/15E148 Safari/604.1'
userAgent3 = 'Mozilla/5.0 (Linux; Android 8.0.0; SM-G930F Build/R16NW; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/74.0.3729.157 Mobile Safari/537.36'
userAgent4 = 'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.90 Safari/537.36'
userAgent5 = 'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Mobile/15E148 Safari/604.1'
userAgent6 = 'Mozilla/5.0 (Linux; Android 8.0.0; SM-G930F Build/R16NW; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/74.0.3729.157 Mobile Safari/537.36'
userAgent7 = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/605.1.15 (KHTML, like Gecko)'
userAgent8 = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/605.1.15 (KHTML, like Gecko)'
userAgent9 = 'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'
userAgent10 = 'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.90 Safari/537.36'
userAgent11 = 'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Mobile/15E148 Safari/604.1'
userAgent12 = 'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'

agents = [userAgent1,userAgent10,userAgent11,userAgent12,userAgent2,userAgent3,userAgent4,userAgent5,userAgent6,userAgent7,userAgent8,userAgent9]

# IPs
ip1 = "2.58.116.34"
ip2 = "5.249.224.34"
ip3 = "198.245.66.112"
ip4 = "2.57.184.34"
ip5 = "161.185.160.93"
ip6 = "142.243.136.34"
ip7 = "161.149.146.201"
ip8 = "23.248.160.34"
ip9 = "194.59.249.171"

ips = [ip1,ip2,ip3,ip4,ip5,ip6,ip7,ip8,ip9]

#Developers
dandee = "dandee@enterprise.com" # Admin - All APIs
grant = "grant@enterprise.com" # Consumer - Recommendation, User, Loyalty
petsell = "petsell@wrong.com" # Catalog - Catalog
hugh = "hugh@startkaleo.com" # Consumer - Recommendation, User, Loyalty
tomjones = "tomjones@enterprise.com" # Catalog - Catalog
joew = "joew@bringiton.com" # Catalog & consumer, Catalog, Recommendation, User, Loyalty
acop = "acop@enterprise.com" # Catalog - Catalog
barbg = "barbg@enterprise.com" # Store & shopping - Catalog, Recommendation, Checkout, Catalog
freds = "freds@bringiton.com" # Consumer - Recommendation, User, Loyalty

def retrieveApiKeyFromDeveloper(developer):
    app = requests.get(url = apigee_url+"developers/"+developer,headers={'Authorization': "Bearer "+token})
    apiKey = requests.get(url = apigee_url+"developers/"+developer+"/apps/"+app.json()['apps'][0],headers={'Authorization': "Bearer "+token})
    appkey = apiKey.json()['credentials'][0]['consumerKey']
    return appkey

apps = { "apps": 
    [
        {
            "developer": dandee,
            "apis": ["catalog","recommendation","user","loyalty","checkout"],
            "weight": 1,
            "apikey": retrieveApiKeyFromDeveloper(dandee) 
        },
        {
            "developer": grant,
            "apis": ["recommendation","user","loyalty"],
            "weight": 4,
            "apikey": retrieveApiKeyFromDeveloper(grant)
        },
        {
            "developer": petsell,
            "apis": ["catalog"],
            "weight": 5,
            "apikey": retrieveApiKeyFromDeveloper(petsell)
        },
        {
            "developer": hugh,
            "apis": ["recommendation","user","loyalty"],
            "weight": 3,
            "apikey": retrieveApiKeyFromDeveloper(hugh)
        },
        {
            "developer": tomjones,
            "apis": ["catalog"],
            "weight": 6,
            "apikey": retrieveApiKeyFromDeveloper(tomjones)
        },
        {
            "developer": joew,
            "apis": ["catalog","recommendation","user","loyalty"],
            "weight": 2,
            "apikey": retrieveApiKeyFromDeveloper(joew)
        },
        {
            "developer": acop,
            "apis": ["catalog"],
            "weight": 8,
            "apikey": retrieveApiKeyFromDeveloper(acop)
        },
        {
            "developer": barbg,
            "apis": ["catalog","recommendation","loyalty","checkout"],
            "weight": 3,
            "apikey": retrieveApiKeyFromDeveloper(barbg)
        },
        {
            "developer": freds,
            "apis": ["recommendation","user","loyalty"],
            "weight": 3,
            "apikey": retrieveApiKeyFromDeveloper(freds)
        }
        
    ]
}

def selectRandomApp(resource):
    json_apps=json.loads(json.dumps(apps))["apps"]
    selected_apps = []
    for temp_app in json_apps:
        for api in temp_app["apis"]:
            if (api == resource):
                i=0
                while i < temp_app["weight"]:
                    selected_apps.append(temp_app["apikey"])
                    i +=1
                break
    return random.choice(selected_apps)



def randomNum():
    return str(random.randint(1,6))

def returnPayload():
    if random.randint(0,100) >= 85:
        return hugePayload
    else:
        return {"content":"something"}

def starting(l):
    print("Starting load")

#Catalog functions
def catalogGetList(l):
    l.client.get("/catalog?apikey="+selectRandomApp("catalog") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def catalogGet(l):
    l.client.get("/catalog/"+randomNum()+"?apikey="+selectRandomApp("catalog") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def catalogPost(l):
    l.client.post("/catalog?apikey="+selectRandomApp("catalog"),{"product":"this is a new product"} ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})

#Checkout functions

def checkoutGetList(l):
    l.client.get("/checkout?apikey="+selectRandomApp("checkout") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def checkoutGet(l):
    l.client.get("/checkout/"+randomNum()+"?apikey="+selectRandomApp("checkout") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def checkoutPost(l):
    l.client.post("/checkout?apikey="+selectRandomApp("checkout"),{"cart":"this is a new cart"} ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})

#Loyalty functions

def loyaltyGetList(l):
    l.client.get("/loyalty?apikey="+selectRandomApp("loyalty") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def loyaltyGet(l):
    l.client.get("/loyalty/"+randomNum()+"?apikey="+selectRandomApp("loyalty") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def loyaltyPost(l):
    l.client.post("/loyalty?apikey="+selectRandomApp("loyalty"),{"loyalty":"this is a new loyalty"} ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})

#Loyalty functions

def recommendationGetList(l):
    l.client.get("/recommendation?apikey="+selectRandomApp("recommendation") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def recommendationGet(l):
    l.client.get("/recommendation/"+randomNum()+"?apikey="+selectRandomApp("recommendation") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def recommendationPost(l):
    l.client.post("/recommendation?apikey="+selectRandomApp("recommendation"),returnPayload() ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})

#Loyalty functions

def userGetList(l):
    l.client.get("/user?apikey="+selectRandomApp("user") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def userGet(l):
    l.client.get("/user/"+randomNum()+"?apikey="+selectRandomApp("user") ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})
def userPost(l):
    l.client.post("/user?apikey="+selectRandomApp("user"),returnPayload() ,headers={"Load-Generator-Version": "2.1","User-Agent":  random.choice(agents),"X-Forwarded-For": random.choice(ips)})


class UserBehavior(TaskSet):

    def on_start(self):
        self.client.verify = False
        starting(self)

    tasks = {
        loyaltyGetList: 1, 
        loyaltyGet: 5,
        loyaltyPost: 1, 
        recommendationGet: 3, 
        recommendationPost: 2, 
        recommendationGetList: 7, 
        userPost: 1, 
        userGet: 5, 
        userPost: 1, 
        checkoutGet: 3, 
        checkoutGetList:1, 
        checkoutPost: 5, 
        catalogGet: 8, 
        catalogGetList: 3, 
        catalogPost: 1}
class WebsiteUser(HttpLocust):
    task_set = UserBehavior
    min_wait=5000
    max_wait=9000