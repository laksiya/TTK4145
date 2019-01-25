# Python 3.3.3 and 2.7.6
# python fo.py

from threading import Thread, Lock
import Queue

# Potentially useful thing:
#   In Python you "import" a global variable, instead of "export"ing it when you declare it
#   (This is probably an effort to make you feel bad about typing the word "global")
i = 0
add_number = Queue.Queue()
lock = Lock()

def incrementingFunction():
    global i, add_number
    for j in range(999999):
        #i=i+1
        lock.acquire()
        i += 1
        lock.release()


def decrementingFunction():
    global i, add_number
    for k in range(1000000):
        #i=i-1
        lock.acquire()
        i -= 1
        lock.release()


def main():
    # TODO: Something is missing here (needed to print i)
    #q = Queue.Queue()
    incrementing = Thread(target=incrementingFunction, args=())
    decrementing = Thread(target=decrementingFunction, args=())

    # TODO: Start both threads
    incrementing.start()
    decrementing.start()
    incrementing.join()
    decrementing.join()

    global i
    print("The magic number is:", i)


main()
