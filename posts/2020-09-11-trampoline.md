---
title: trampoline
author: ssledz
description: Trampoline technical trick
---

### Recursive tail call optimization

![recursion-vs-trampolining](/images/recursion-vs-trampolining.png)

Tail call optimization (or tail call elimination) allows recursive functions to re-use the stack frame instead of 
creating new frames on every call.

Thanks to that an author of recursive function in tail position is not constrained by the stack size. More over such
a function runs faster than the function without optimization, because calling a function doesn't 
create a new stack frame which is time and resource consuming operation.

Let's consider a function without a recursive call in tail position

```scala
def fact(n: Int): Long = 
  if (n <= 1) 1 else n * fact(n - 1)
```

In order to compute __fact(n)__ we need first to compute __fact(n - 1)__ and multiple a result by __n__. This process ends
on a base case when we know that the __fact(1)__ is just __1__. This schema can be described formally 
using following recursive formula.

```
fact(1) = 1
fact(n) = n * fact(n - 1)
```

You can spot that the formula, and the implementation are almost identical, and this is a great advantage of using 
recursive functions. It makes code more readable and less error prone. 

Let's try to apply a __fact__ with __5__

```
fact(5) = 5 * fact(4)
fact(4) = 4 * fact(3)
fact(3) = 3 * fact(2)
fact(2) = 2 * fact(1)
fact(1) = 1

fact(5) = (5 * (4 * (3 * (2 * (1)))))
``` 

Each call creates a new function frame on a stack (the call is mark by __(..)__) and because this call is not in a tail
position a compiler can't optimize this.

It turns out that __fact__ can be slightly rewritten to have a recursive call in tail position. Take a look on __fact2__.

```scala
def fact2(n: Int): Long = {
  def go(m: Long, acc: Long): Long =
    if (m <= 1) acc else go(m - 1, m * acc)
  go(n, 1)
}
```

Here I introduced a helper function __go__ which takes a role of stack safe iteration. Why this recursive call is stack safe?
It is stack safe because the last recursive function call is the last instruction to do, and a compiler is aware of that.
The compiler can utilize the current stack frame just by substituting the function parameters with the ones computed during the call.
To have a better understanding we can simply assume that the compiler for optimization purpose rewrites __fact2__ to __fact3__.

```scala
def fact3(n: Int): Long = {
  var m = n
  var acc = 1L
  while (!(m <= 1)) {
    acc = acc * m
    m = m - 1
  }
  acc
}
```

__fact3__ uses imperative while loop to compute factorial which doesn't introduce any new stack frames.

### Limitation

Let's consider a simple algorithm of checking if a given number is _even_ or _odd_.

```scala
object NotStackSafe {
  def even(n: Long): Boolean =
    if (n == 0) true else odd(n - 1)
  private def odd(n: Long): Boolean =
    if (n == 0) false else even(n - 1)
}
```

Even if the function calls are in tail positions, for __n__ large enough we can notice __stack overflow__. 

```scala
assert(NotStackSafe.even(0) == true)
assert(NotStackSafe.even(1) == false)
assert(NotStackSafe.even(13) == false)
// assert(NotStackSafe.even(100000) == true) // bum !
```

The sad true is that tail call optimization in the Scala compiler is limited to self-recursive methods.  

Is there any way to deal with such constrained? It turns out that there is a solution in a form of simple technical trick.

### Trampoline

A trampoline is a some kind of function interpreter. It can do two things: 
* resume a suspended function call 
* return a value computed by function to the caller side

A function running by a trampoline needs to be properly adjusted:
* if a function wants to make a call (might be recursive), it has to return the suspension instruction
* if a function wants to return a final result, it has to return an instruction describing the result

The interpretation process looks following:
* trampoline calls a function
* function returns the instruction
* trampoline interprets the instruction, and in case of suspension repeats the process
* in case of final result trampoline returns the value to its caller

All function calls are done via the trampoline. When a function has to call another function, instead of calling it directly, 
it provides the address of the function to be called and the arguments to the trampoline. This ensures that the stack 
does not grow and iteration can continue indefinitely.

We can model instructions using simple _ADT_
 
```scala
sealed trait Trampoline[A]
case class Return[A](a: A) extends Trampoline[A]
case class Suspend[A](resume: () => Trampoline[A]) extends Trampoline[A]
```

__Trampoline__ data type has two data constructors
* __Return__ -- indicates that the function wants to return a value to the caller side
* __Suspend__ -- suspends a function call (trampoline can resume)

Functions __even__ and __odd__ now can be rewritten respectively

```scala
object StackSafe {
  def even(n: Long): Trampoline[Boolean] =
    if (n == 0) Return(true) else Suspend(() => odd(n - 1))
  private def odd(n: Long): Trampoline[Boolean] =
    if (n == 0) Return(false) else Suspend(() => even(n - 1))
}
```

The last piece of puzzle is an interpreter which is quite simple

```scala
sealed trait Trampoline[A] {
  def runT: A = {
    def go(curr: Trampoline[A]): A = curr match {
      case Return(a) => a
      case Suspend(resume) => go(resume())
    }
    go(this)
  }
}
```

Now we can try to run again the function __even__ with large numbers, not being afraid of __stack overflow__ 

```scala
assert(StackSafe.even(0).runT == true)
assert(StackSafe.even(1).runT == false)
assert(StackSafe.even(13).runT == false)
assert(StackSafe.even(100000).runT == true)
```