import inspect, app.services.pet_ai as m
print('file:', m.__file__)
print('names:', [n for n in dir(m) if 'Client' in n])
print('source head>>>')
print(inspect.getsource(m)[:800])
