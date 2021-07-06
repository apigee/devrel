import time
import random

def getCatalog(id):
    sleepTime = random.randint(1,100)
    print("random sleep: ",sleepTime)
    if id == 1:
        product = {
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
        product = {
            "id": "66VCHSJNUP",
            "name": "Vintage Camera Lens",
            "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed et tortor elit. Vivamus nibh orci, auctor eu pharetra sit amet, finibus et turpis. Nullam scelerisque vel lorem et condimentum. Pellentesque a est nulla. Praesent molestie cursus commodo. Integer ac odio at arcu imperdiet volutpat ut et velit. Ut viverra pellentesque elit eget mattis. Maecenas et convallis risus. Aenean sem nisl, cursus sit amet faucibus eget, lacinia eget sapien. Aenean eu elementum mi, condimentum pharetra ante. Aliquam scelerisque malesuada purus.Etiam elementum libero neque, id pellentesque lectus sodales non. Suspendisse dui arcu, vehicula quis diam semper, tempus elementum nulla. Duis ut ipsum ut ex mollis malesuada sed ultrices nisl. Etiam sit amet massa vestibulum, imperdiet nunc ac, sagittis massa. Nulla quis orci sit amet sem faucibus malesuada. Sed ut eros placerat, consequat nisl facilisis, accumsan diam. Phasellus eleifend velit non iaculis aliquet. Etiam ac dolor tincidunt, luctus metus et, luctus erat. Praesent fermentum sed dui et fermentum. Donec nec pretium neque, eu vulputate urna. Donec non metus sit amet velit interdum viverra. Praesent non luctus velit. Maecenas velit arcu, suscipit sed mauris et, ultrices ullamcorper arcu. Phasellus commodo magna metus, vel mollis arcu aliquam non. Nunc rhoncus velit nisi, a fermentum eros luctus nec.Cras cursus tempus velit, vel commodo ex dapibus a. Sed nec commodo libero, semper iaculis purus. Praesent faucibus, mi vitae scelerisque feugiat, ligula dui dictum quam, eget porta neque quam ac ligula. Ut ullamcorper ipsum quis urna ornare, vitae consequat nibh viverra. Curabitur semper feugiat nunc et ultrices. Suspendisse id tellus in velit auctor elementum vitae in enim. Nunc eu venenatis risus. Sed sed purus magna. Proin nec facilisis eros. Donec et elit id risus tristique congue ut nec lectus. Sed augue mi, accumsan non ligula vel, dapibus lacinia mauris. Mauris quam arcu, congue et sapien eu, consectetur placerat nisl. Nam finibus quam pulvinar vehicula placerat.Quisque rhoncus sapien quis turpis lacinia, egestas congue neque placerat. Phasellus eu bibendum quam. Proin quis justo erat. Nam faucibus lorem iaculis, aliquam risus non, vulputate sapien. Ut gravida interdum mauris vel rutrum. Nullam tortor est, bibendum at nibh quis, tincidunt rutrum tellus. Integer luctus ante eu sapien euismod, a tempus quam congue. Donec ullamcorper posuere leo, vel condimentum purus venenatis ut. Maecenas in faucibus justo, convallis euismod sem. In ut magna vel est blandit porta. Ut et porta lorem, et scelerisque tortor. Curabitur faucibus, velit vel tristique aliquam, leo nibh porta sem, at euismod augue tortor a sapien. Maecenas sit amet augue id ipsum dictum malesuada id ac ligula. Fusce vel fringilla nisl, nec hendrerit sapien.Vestibulum lorem nisl, cursus varius lacus quis, eleifend posuere sem. Cras vehicula faucibus diam a vehicula. Etiam tincidunt malesuada porta. Aliquam erat volutpat. Integer nec diam diam. Nullam tortor lorem, rutrum nec consectetur vitae, gravida a purus. Nullam vehicula eros libero, non consectetur ligula imperdiet nec. Quisque malesuada justo mi, at tincidunt neque pharetra et. Duis vitae magna eu libero malesuada dictum. Maecenas sit amet ornare velit. Maecenas egestas velit egestas felis dignissim blandit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed et tortor elit. Vivamus nibh orci, auctor eu pharetra sit amet, finibus et turpis. Nullam scelerisque vel lorem et condimentum. Pellentesque a est nulla. Praesent molestie cursus commodo. Integer ac odio at arcu imperdiet volutpat ut et velit. Ut viverra pellentesque elit eget mattis. Maecenas et convallis risus. Aenean sem nisl, cursus sit amet faucibus eget, lacinia eget sapien. Aenean eu elementum mi, condimentum pharetra ante. Aliquam scelerisque malesuada purus.Etiam elementum libero neque, id pellentesque lectus sodales non. Suspendisse dui arcu, vehicula quis diam semper, tempus elementum nulla. Duis ut ipsum ut ex mollis malesuada sed ultrices nisl. Etiam sit amet massa vestibulum, imperdiet nunc ac, sagittis massa. Nulla quis orci sit amet sem faucibus malesuada. Sed ut eros placerat, consequat nisl facilisis, accumsan diam. Phasellus eleifend velit non iaculis aliquet. Etiam ac dolor tincidunt, luctus metus et, luctus erat. Praesent fermentum sed dui et fermentum. Donec nec pretium neque, eu vulputate urna. Donec non metus sit amet velit interdum viverra. Praesent non luctus velit. Maecenas velit arcu, suscipit sed mauris et, ultrices ullamcorper arcu. Phasellus commodo magna metus, vel mollis arcu aliquam non. Nunc rhoncus velit nisi, a fermentum eros luctus nec.Cras cursus tempus velit, vel commodo ex dapibus a. Sed nec commodo libero, semper iaculis purus. Praesent faucibus, mi vitae scelerisque feugiat, ligula dui dictum quam, eget porta neque quam ac ligula. Ut ullamcorper ipsum quis urna ornare, vitae consequat nibh viverra. Curabitur semper feugiat nunc et ultrices. Suspendisse id tellus in velit auctor elementum vitae in enim. Nunc eu venenatis risus. Sed sed purus magna. Proin nec facilisis eros. Donec et elit id risus tristique congue ut nec lectus. Sed augue mi, accumsan non ligula vel, dapibus lacinia mauris. Mauris quam arcu, congue et sapien eu, consectetur placerat nisl. Nam finibus quam pulvinar vehicula placerat.Quisque rhoncus sapien quis turpis lacinia, egestas congue neque placerat. Phasellus eu bibendum quam. Proin quis justo erat. Nam faucibus lorem iaculis, aliquam risus non, vulputate sapien. Ut gravida interdum mauris vel rutrum. Nullam tortor est, bibendum at nibh quis, tincidunt rutrum tellus. Integer luctus ante eu sapien euismod, a tempus quam congue. Donec ullamcorper posuere leo, vel condimentum purus venenatis ut. Maecenas in faucibus justo, convallis euismod sem. In ut magna vel est blandit porta. Ut et porta lorem, et scelerisque tortor. Curabitur faucibus, velit vel tristique aliquam, leo nibh porta sem, at euismod augue tortor a sapien. Maecenas sit amet augue id ipsum dictum malesuada id ac ligula. Fusce vel fringilla nisl, nec hendrerit sapien.Vestibulum lorem nisl, cursus varius lacus quis, eleifend posuere sem. Cras vehicula faucibus diam a vehicula. Etiam tincidunt malesuada porta. Aliquam erat volutpat. Integer nec diam diam. Nullam tortor lorem, rutrum nec consectetur vitae, gravida a purus. Nullam vehicula eros libero, non consectetur ligula imperdiet nec. Quisque malesuada justo mi, at tincidunt neque pharetra et. Duis vitae magna eu libero malesuada dictum. Maecenas sit amet ornare velit. Maecenas egestas velit egestas felis dignissim blandit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed et tortor elit. Vivamus nibh orci, auctor eu pharetra sit amet, finibus et turpis. Nullam scelerisque vel lorem et condimentum. Pellentesque a est nulla. Praesent molestie cursus commodo. Integer ac odio at arcu imperdiet volutpat ut et velit. Ut viverra pellentesque elit eget mattis. Maecenas et convallis risus. Aenean sem nisl, cursus sit amet faucibus eget, lacinia eget sapien. Aenean eu elementum mi, condimentum pharetra ante. Aliquam scelerisque malesuada purus.Etiam elementum libero neque, id pellentesque lectus sodales non. Suspendisse dui arcu, vehicula quis diam semper, tempus elementum nulla. Duis ut ipsum ut ex mollis malesuada sed ultrices nisl. Etiam sit amet massa vestibulum, imperdiet nunc ac, sagittis massa. Nulla quis orci sit amet sem faucibus malesuada. Sed ut eros placerat, consequat nisl facilisis, accumsan diam. Phasellus eleifend velit non iaculis aliquet. Etiam ac dolor tincidunt, luctus metus et, luctus erat. Praesent fermentum sed dui et fermentum. Donec nec pretium neque, eu vulputate urna. Donec non metus sit amet velit interdum viverra. Praesent non luctus velit. Maecenas velit arcu, suscipit sed mauris et, ultrices ullamcorper arcu. Phasellus commodo magna metus, vel mollis arcu aliquam non. Nunc rhoncus velit nisi, a fermentum eros luctus nec.Cras cursus tempus velit, vel commodo ex dapibus a. Sed nec commodo libero, semper iaculis purus. Praesent faucibus, mi vitae scelerisque feugiat, ligula dui dictum quam, eget porta neque quam ac ligula. Ut ullamcorper ipsum quis urna ornare, vitae consequat nibh viverra. Curabitur semper feugiat nunc et ultrices. Suspendisse id tellus in velit auctor elementum vitae in enim. Nunc eu venenatis risus. Sed sed purus magna. Proin nec facilisis eros. Donec et elit id risus tristique congue ut nec lectus. Sed augue mi, accumsan non ligula vel, dapibus lacinia mauris. Mauris quam arcu, congue et sapien eu, consectetur placerat nisl. Nam finibus quam pulvinar vehicula placerat.Quisque rhoncus sapien quis turpis lacinia, egestas congue neque placerat. Phasellus eu bibendum quam. Proin quis justo erat. Nam faucibus lorem iaculis, aliquam risus non, vulputate sapien. Ut gravida interdum mauris vel rutrum. Nullam tortor est, bibendum at nibh quis, tincidunt rutrum tellus. Integer luctus ante eu sapien euismod, a tempus quam congue. Donec ullamcorper posuere leo, vel condimentum purus venenatis ut. Maecenas in faucibus justo, convallis euismod sem. In ut magna vel est blandit porta. Ut et porta lorem, et scelerisque tortor. Curabitur faucibus, velit vel tristique aliquam, leo nibh porta sem, at euismod augue tortor a sapien. Maecenas sit amet augue id ipsum dictum malesuada id ac ligula. Fusce vel fringilla nisl, nec hendrerit sapien.Vestibulum lorem nisl, cursus varius lacus quis, eleifend posuere sem. Cras vehicula faucibus diam a vehicula. Etiam tincidunt malesuada porta. Aliquam erat volutpat. Integer nec diam diam. Nullam tortor lorem, rutrum nec consectetur vitae, gravida a purus. Nullam vehicula eros libero, non consectetur ligula imperdiet nec. Quisque malesuada justo mi, at tincidunt neque pharetra et. Duis vitae magna eu libero malesuada dictum. Maecenas sit amet ornare velit. Maecenas egestas velit egestas felis dignissim blandit.",           "picture": "/static/img/products/camera-lens.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "12",
                "nanos": 490000000
            },
            "categories": [
                "photography",
                "vintage"
            ]
        }
        
    elif id == 3:
        product = {
            "id": "L9ECAV7KIM",
            "name": "Terrarium",
            "description": "This terrarium will looks great in your white painted living room.",
            "picture": "/static/img/products/terrarium.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "36",
                "nanos": 450000000
            },
            "categories": [
                "gardening"
            ]
        }
    elif id == 4:
        product = {
            "id": "2ZYFJ3GM2N",
            "name": "Film Camera",
            "description": "This camera looks like it's a film camera, but it's actually digital.",
            "picture": "/static/img/products/film-camera.jpg",
            "priceUsd": {
                "currencyCode": "USD",
                "units": "2245"
            },
            "categories": [
                "photography",
                "vintage"
            ]
        }
    else:
        return False
    if sleepTime == id:
        print("sleeping")
        time.sleep (random.randint(0,7))
    return product