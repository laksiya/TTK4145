// Use `go run foo.go` to run your program

package main

import (
    . "fmt"
    //"runtime"
)

// Control signals
const (
	GetNumber = iota
	Exit
)

func number_server(add_number <-chan int, control <-chan int, number chan<- int) {
	var i = 0

	for {
		select {
			case z:=<-add_number:
				i+=z
			case <- control:
				number <- i
				return
			// TODO: receive different messages and handle them correctly
			// You will at least need to update the number and handle control signals.
		}
	}
}

func incrementing(add_number chan<-int, finished chan<- bool) {
	for j := 0; j<1000000; j++ {
		add_number <- 1
	}
	//TODO: signal that the goroutine is finished
	finished <- true
}

func decrementing(add_number chan<- int, finished chan<- bool) {
	for j := 0; j<1000000; j++ {
		add_number <- -1
	}
	//TODO: signal that the goroutine is finished
	finished <- true
}

func main() {
//runtime.GOMAXPROCS(runtime.NumCPU())
	// TODO: Construct the required channels

  add_number := make(chan int)
  control := make(chan int)
  number := make(chan int)
  finished := make(chan bool)

	// Think about wether the receptions of the number should be unbuffered, or buffered with a fixed queue size.

	// TODO: Spawn the required goroutines

	go incrementing(add_number,finished)
	go decrementing(add_number,finished)
  go number_server(add_number, control, number)
	<- finished
	<- finished
	// TODO: block on finished from both "worker" goroutines

	control<-GetNumber
	Println("The magic number is:", <- number)
}
