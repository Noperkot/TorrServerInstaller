import platform

try:
    with open('build.cnt', 'r') as f:
        cnt = int(f.read())  
except Exception as error:
    cnt = 0
    
cnt += 1
print('Now BUILD={}'.format(cnt))

with open('build.cnt', 'w') as f:
    f.write(str(cnt))
    
with open('build.nsh', 'w') as f:
    f.write('!define BUILD "{}"\n'.format(cnt))
    f.write('!define OS "{}-{}"\n'.format(platform.system(), platform.machine()))