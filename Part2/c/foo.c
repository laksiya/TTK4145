#include <pthread.h>
#include <stdio.h>

int i = 0;
pthread_mutex_t source;

// Note the return type: void*
void* incrementingThreadFunction(void* arg){
    // increment i 1_000_000 times
	for (int k = 0; k < 10000000; k++ ) {
    pthread_mutex_lock(&source);
    i++;
    pthread_mutex_unlock(&source);
  }
    return NULL;
}

void* decrementingThreadFunction(void* arg){
    //  decrement i 1_000_000 times
	for(int k =10000000 ; k > 0 ; k-- ) {
    pthread_mutex_lock(&source);
    i--;
    pthread_mutex_unlock(&source);
  }
    return NULL;
}


int main(){
    //  declare incrementingThread and decrementingThread (hint: google pthread_create)
	pthread_t incrementingThread;
	pthread_t decrementingThread;

    pthread_create(&decrementingThread, NULL, decrementingThreadFunction, NULL);
    pthread_create(&incrementingThread, NULL, incrementingThreadFunction, NULL);



		pthread_join(incrementingThread, NULL);
    pthread_join(decrementingThread, NULL);
		//decrementingThreadFunction();
    printf("The magic number is: %d\n", i);
    return 0;
}
