#! /bin/bash

# Minimum number of task parameters: 2
if [ "$1" -le 1 ] ; then k=2; else k=$1; fi

# Copyright notice:
echo "/* 
 * Copyright 2013-2016 Formal Methods and Tools, University of Twente
 * Copyright 2016-2017 Tom van Dijk, Johannes Kepler University Linz
 * Copyright 2019-2021 Tom van Dijk, Formal Methods and Tools, University of Twente
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */"

echo '
#include <assert.h>
#include <unistd.h>
#include <stdint.h>
#include <stdio.h>
#include <pthread.h> /* for pthread_t */

#ifndef __cplusplus
  #include <stdatomic.h>
#else
  // Compatibility with C11
  #include <atomic>
  #define _Atomic(T) std::atomic<T>
  using std::memory_order_relaxed;
  using std::memory_order_acquire;
  using std::memory_order_release;
  using std::memory_order_seq_cst;
#endif

#include <lace_config.h>

#ifndef __LACE_H__
#define __LACE_H__

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * Using Lace.
 *
 * Optionally set the verbosity level with lace_set_verbosity.
 * Optionally set the default program stack size of each worker thread with lace_set_stacksize.
 *
 * Then call lace_start to start Lace workers.
 * - lace_start(n_workers, deque_size);
 *   set both parameters to 0 for reasonable defaults, using all available cores.
 *
 * After this, you can run tasks using the RUN(...)
 *
 * Use lace_suspend and lace_resume to temporarily stop running, or lace_stop to completely stop Lace.
 */

/**
 * Type definitions used in the functions below.
 * - WorkerP contains the (private) Worker data
 * - Task contains a single Task
 */
typedef struct _WorkerP WorkerP;
typedef struct _Task Task;

/**
 * The macro LACE_TYPEDEF_CB(typedefname, taskname, parametertypes) defines
 * a Task for use as a callback function.
 */
#define LACE_TYPEDEF_CB(t, f, ...) typedef t (*f)(WorkerP *, Task *, ##__VA_ARGS__);

/**
 * Set verbosity level (0 = no startup messages, 1 = startup messages)
 * Default level: 0
 */
void lace_set_verbosity(int level);

/**
 * Set the program stack size of Lace worker threads. (Not really needed, default is OK.)
 */
void lace_set_stacksize(size_t stacksize);

/**
 * Get the program stack size of Lace worker threads.
 * If this returns 0, it uses the default.
 */
size_t lace_get_stacksize(void);

/**
 * Get the number of available PUs (hardware threads)
 */
unsigned int lace_get_pu_count(void);

/**
 * Start Lace with <n_workers> workers and a a task deque size of <dqsize> per worker.
 * If <n_workers> is set to 0, automatically detects available cores.
 * If <dqsize> is est to 0, uses a reasonable default value.
 */
void lace_start(unsigned int n_workers, size_t dqsize);

/**
 * Suspend all workers.
 * Call this method from outside Lace threads.
 */
void lace_suspend(void);

/**
 * Resume all workers.
 * Call this method from outside Lace threads.
 */
void lace_resume(void);

/**
 * Stop Lace.
 * Call this method from outside Lace threads.
 */
void lace_stop(void);

/**
 * Steal a random task.
 * Only use this from inside a Lace task.
 */
#define lace_steal_random() CALL(lace_steal_random)
void lace_steal_random_CALL(WorkerP*, Task*);

/**
 * Enter the Lace barrier. (all active workers must enter it before we can continue)
 * Only run this from inside a Lace task.
 */
void lace_barrier(void);

/**
 * Retrieve the number of Lace workers
 */
unsigned int lace_workers(void);

/**
 * Retrieve whether we are running in a Lace worker. Returns 1 if this is the case, 0 otherwise.
 */
int lace_is_worker(void);

/**
 * Retrieve the current worker data.
 * Only run this from inside a Lace task.
 * (Used by LACE_VARS)
 */
WorkerP *lace_get_worker(void);

/**
 * Retrieve the current head of the deque of the worker.
 * (Used by LACE_VARS)
 */
Task *lace_get_head(WorkerP *);

/**
 * Helper function to call from outside Lace threads.
 * This helper function is used by the _RUN methods for the RUN() macro.
 */
void lace_run_task(Task *task);

/**
 * Helper function to call from outside Lace threads.
 * This helper function is used by the _RUN methods for the RUN() macro.
 */
void lace_run_task_exclusive(Task *task);

/**
 * Helper function to start a new task execution (task frame) on a given task.
 * This helper function is used by the _NEWFRAME methods for the NEWFRAME() macro
 * Only when the task is done, do workers continue with the previous task frame.
 */
void lace_run_newframe(Task *task);

/**
 * Helper function to make all run a given task together.
 * This helper function is used by the _TOGETHER methods for the TOGETHER() macro
 * They all start the task in a lace_barrier and complete it with a lace barrier.
 * Meaning they all start together, and all end together.
 */
void lace_run_together(Task *task);

/**
 * Create a pointer to a Tasks main function.
 */
#define TASK(f)           ( f##_CALL )

/**
 * Call a Tasks implementation (adds Lace variables to call)
 */
#define WRAP(f, ...)      ( f((WorkerP *)__lace_worker, (Task *)__lace_dq_head, ##__VA_ARGS__) )

/**
 * Sync a task.
 */
#define SYNC(f)           ( __lace_dq_head--, WRAP(f##_SYNC) )

/**
 * Sync a task, but if the task is not stolen, then do not execute it.
 */
#define DROP()            ( __lace_dq_head--, WRAP(lace_drop) )

/**
 * Spawn a task.
 */
#define SPAWN(f, ...)     ( WRAP(f##_SPAWN, ##__VA_ARGS__), __lace_dq_head++ )

/**
 * Directly execute a task from inside a Lace thread.
 */
#define CALL(f, ...)      ( WRAP(f##_CALL, ##__VA_ARGS__) )

/**
 * Directly execute a task from outside Lace threads.
 */
#define RUN(f, ...)    ( f##_RUN ( __VA_ARGS__ ) )
#define RUNEX(f, ...)    ( f##_RUNEX ( __VA_ARGS__ ) )

/**
 * Signal all workers to interrupt their current tasks and instead perform (a personal copy of) the given task.
 */
#define TOGETHER(f, ...)  ( f##_TOGETHER ( __VA_ARGS__) )

/**
 * Signal all workers to interrupt their current tasks and help the current thread with the given task.
 */
#define NEWFRAME(f, ...)  ( f##_NEWFRAME ( __VA_ARGS__) )

/**
 * (Try to) steal a task from a random worker.
 */
#define STEAL_RANDOM()    ( CALL(lace_steal_random) )

/**
 * Get the current worker id.
 */
#define LACE_WORKER_ID    ( __lace_worker->worker )

/**
 * Get the core where the current worker is pinned.
 */
#define LACE_WORKER_PU    ( __lace_worker->pu )

/**
 * Initialize local variables __lace_worker and __lace_dq_head which are required for most Lace functionality.
 * This only works inside a Lace thread.
 */
#define LACE_VARS WorkerP * __attribute__((unused)) __lace_worker = lace_get_worker(); Task * __attribute__((unused)) __lace_dq_head = lace_get_head(__lace_worker);

/**
 * Check if current tasks must be interrupted, and if so, interrupt.
 */
void lace_yield(WorkerP *__lace_worker, Task *__lace_dq_head);
#define YIELD_NEWFRAME() { if (unlikely(atomic_load_explicit(&lace_newframe.t, memory_order_relaxed) != NULL)) lace_yield(__lace_worker, __lace_dq_head); }

/**
 * True if the given task is stolen, False otherwise.
 */
#define TASK_IS_STOLEN(t) ((size_t)t->thief > 1)

/**
 * True if the given task is completed, False otherwise.
 */
#define TASK_IS_COMPLETED(t) ((size_t)t->thief == 2)

/**
 * Retrieves a pointer to the result of the given task.
 */
#define TASK_RESULT(t) (&t->d[0])

/**
 * Compute a random number, thread-local (so scalable)
 */
#define LACE_TRNG (__lace_worker->rng = 2862933555777941757ULL * __lace_worker->rng + 3037000493ULL)

/* Some flags that influence Lace behavior */

#ifndef LACE_LEAP_RANDOM /* Use random leaping when leapfrogging fails */
#define LACE_LEAP_RANDOM 1
#endif

#ifndef LACE_COUNT_EVENTS
#define LACE_COUNT_EVENTS (LACE_PIE_TIMES || LACE_COUNT_TASKS || LACE_COUNT_STEALS || LACE_COUNT_SPLITS)
#endif

/**
 * Now follows the implementation of Lace
 */

/* Typical cacheline size of system architectures */
#ifndef LINE_SIZE
#define LINE_SIZE 64
#endif

/* The size of a pointer, 8 bytes on a 64-bit architecture */
#define P_SZ (sizeof(void *))

#define PAD(x,b) ( ( (b) - ((x)%(b)) ) & ((b)-1) ) /* b must be power of 2 */
#define ROUND(x,b) ( (x) + PAD( (x), (b) ) )

/* The size is in bytes. Note that this is without the extra overhead from Lace.
   The value must be greater than or equal to the maximum size of your tasks.
   The task size is the maximum of the size of the result or of the sum of the parameter sizes. */
#ifndef LACE_TASKSIZE
#define LACE_TASKSIZE ('$k')*P_SZ
#endif

/* Compiler specific branch prediction optimization */
#ifndef likely
#define likely(x)       __builtin_expect((x),1)
#endif

#ifndef unlikely
#define unlikely(x)     __builtin_expect((x),0)
#endif

#if LACE_PIE_TIMES
/* High resolution timer */
static inline uint64_t gethrtime()
{
    uint32_t hi, lo;
    asm volatile ("rdtsc" : "=a"(lo), "=d"(hi) :: "memory");
    return (uint64_t)hi<<32 | lo;
}
#endif

#if LACE_COUNT_EVENTS
void lace_count_reset();
void lace_count_report_file(FILE *file);
#endif

#if LACE_COUNT_TASKS
#define PR_COUNTTASK(s) PR_INC(s,CTR_tasks)
#else
#define PR_COUNTTASK(s) /* Empty */
#endif

#if LACE_COUNT_STEALS
#define PR_COUNTSTEALS(s,i) PR_INC(s,i)
#else
#define PR_COUNTSTEALS(s,i) /* Empty */
#endif

#if LACE_COUNT_SPLITS
#define PR_COUNTSPLITS(s,i) PR_INC(s,i)
#else
#define PR_COUNTSPLITS(s,i) /* Empty */
#endif

#if LACE_COUNT_EVENTS
#define PR_ADD(s,i,k) ( ((s)->ctr[i])+=k )
#else
#define PR_ADD(s,i,k) /* Empty */
#endif
#define PR_INC(s,i) PR_ADD(s,i,1)

typedef enum {
#ifdef LACE_COUNT_TASKS
    CTR_tasks,       /* Number of tasks spawned */
#endif
#ifdef LACE_COUNT_STEALS
    CTR_steal_tries, /* Number of steal attempts */
    CTR_leap_tries,  /* Number of leap attempts */
    CTR_steals,      /* Number of succesful steals */
    CTR_leaps,       /* Number of succesful leaps */
    CTR_steal_busy,  /* Number of steal busies */
    CTR_leap_busy,   /* Number of leap busies */
#endif
#ifdef LACE_COUNT_SPLITS
    CTR_split_grow,  /* Number of split right */
    CTR_split_shrink,/* Number of split left */
    CTR_split_req,   /* Number of split requests */
#endif
    CTR_fast_sync,   /* Number of fast syncs */
    CTR_slow_sync,   /* Number of slow syncs */
#ifdef LACE_PIE_TIMES
    CTR_init,        /* Timer for initialization */
    CTR_close,       /* Timer for shutdown */
    CTR_wapp,        /* Timer for application code (steal) */
    CTR_lapp,        /* Timer for application code (leap) */
    CTR_wsteal,      /* Timer for steal code (steal) */
    CTR_lsteal,      /* Timer for steal code (leap) */
    CTR_wstealsucc,  /* Timer for succesful steal code (steal) */
    CTR_lstealsucc,  /* Timer for succesful steal code (leap) */
    CTR_wsignal,     /* Timer for signal after work (steal) */
    CTR_lsignal,     /* Timer for signal after work (leap) */
#endif
    CTR_MAX
} CTR_index;

#define THIEF_EMPTY     ((struct _Worker*)0x0)
#define THIEF_TASK      ((struct _Worker*)0x1)
#define THIEF_COMPLETED ((struct _Worker*)0x2)

#define TASK_COMMON_FIELDS(type)                               \
    void (*f)(struct _WorkerP *, struct _Task *, struct type *);  \
    _Atomic(struct _Worker*) thief;

struct __lace_common_fields_only { TASK_COMMON_FIELDS(_Task) };
#define LACE_COMMON_FIELD_SIZE sizeof(struct __lace_common_fields_only)

static_assert((LACE_COMMON_FIELD_SIZE % P_SZ) == 0, "LACE_COMMON_FIELD_SIZE is not a multiple of P_SZ");

typedef struct _Task {
    TASK_COMMON_FIELDS(_Task)
    char d[LACE_TASKSIZE];
//    char d[LACE_TASKSIZE];
//    char p2[PAD(ROUND(LACE_COMMON_FIELD_SIZE, P_SZ) + LACE_TASKSIZE, LINE_SIZE)];
} Task;

static_assert((sizeof(Task) % LINE_SIZE) == 0, "Task size should be a multiple of LINE_SIZE");

/* hopefully packed? */
typedef union {
    struct {
        _Atomic(uint32_t) tail;
        _Atomic(uint32_t) split;
    } ts;
    _Atomic(uint64_t) v;
} TailSplit;

typedef union {
    struct {
        uint32_t tail;
        uint32_t split;
    } ts;
    uint64_t v;
} TailSplitNA;

typedef struct _Worker {
    Task *dq;
    TailSplit ts;
    uint8_t allstolen;

    char pad1[PAD(P_SZ+sizeof(TailSplit)+1, LINE_SIZE)];

    uint8_t movesplit;
} Worker;

typedef struct _WorkerP {
    Task *dq;                   // same as dq
    Task *split;                // same as dq+ts.ts.split
    Task *end;                  // dq+dq_size
    Worker *_public;            // pointer to public Worker struct
    uint64_t rng;               // my random seed (for lace_trng)
    uint32_t seed;              // my random seed (for lace_steal_random)
    uint16_t worker;            // what is my worker id?
    uint8_t allstolen;          // my allstolen

#if LACE_COUNT_EVENTS
    uint64_t ctr[CTR_MAX];      // counters
    uint64_t time;
    int level;
#endif

    int16_t pu;                 // my pu (for HWLOC)
} WorkerP;

#define LACE_STOLEN   ((Worker*)0)
#define LACE_BUSY     ((Worker*)1)
#define LACE_NOWORK   ((Worker*)2)

void lace_abort_stack_overflow(void) __attribute__((noreturn));

typedef struct
{
    _Atomic(Task*) t;
    char pad[LINE_SIZE-sizeof(Task *)];
} lace_newframe_t;

extern lace_newframe_t lace_newframe;

/**
 * Make all tasks of the current worker shared.
 */
#define LACE_MAKE_ALL_SHARED() lace_make_all_shared(__lace_worker, __lace_dq_head)
static inline void __attribute__((unused))
lace_make_all_shared( WorkerP *w, Task *__lace_dq_head)
{
    if (w->split != __lace_dq_head) {
        w->split = __lace_dq_head;
        w->_public->ts.ts.split = __lace_dq_head - w->dq;
    }
}

#if LACE_PIE_TIMES
static void lace_time_event( WorkerP *w, int event )
{
    uint64_t now = gethrtime(),
             prev = w->time;

    switch( event ) {

        // Enter application code
        case 1 :
            if(  w->level /* level */ == 0 ) {
                PR_ADD( w, CTR_init, now - prev );
                w->level = 1;
            } else if( w->level /* level */ == 1 ) {
                PR_ADD( w, CTR_wsteal, now - prev );
                PR_ADD( w, CTR_wstealsucc, now - prev );
            } else {
                PR_ADD( w, CTR_lsteal, now - prev );
                PR_ADD( w, CTR_lstealsucc, now - prev );
            }
            break;

            // Exit application code
        case 2 :
            if( w->level /* level */ == 1 ) {
                PR_ADD( w, CTR_wapp, now - prev );
            } else {
                PR_ADD( w, CTR_lapp, now - prev );
            }
            break;

            // Enter sync on stolen
        case 3 :
            if( w->level /* level */ == 1 ) {
                PR_ADD( w, CTR_wapp, now - prev );
            } else {
                PR_ADD( w, CTR_lapp, now - prev );
            }
            w->level++;
            break;

            // Exit sync on stolen
        case 4 :
            if( w->level /* level */ == 1 ) {
                fprintf( stderr, "This should not happen, level = %d\n", w->level );
            } else {
                PR_ADD( w, CTR_lsteal, now - prev );
            }
            w->level--;
            break;

            // Return from failed steal
        case 7 :
            if( w->level /* level */ == 0 ) {
                PR_ADD( w, CTR_init, now - prev );
            } else if( w->level /* level */ == 1 ) {
                PR_ADD( w, CTR_wsteal, now - prev );
            } else {
                PR_ADD( w, CTR_lsteal, now - prev );
            }
            break;

            // Signalling time
        case 8 :
            if( w->level /* level */ == 1 ) {
                PR_ADD( w, CTR_wsignal, now - prev );
                PR_ADD( w, CTR_wsteal, now - prev );
            } else {
                PR_ADD( w, CTR_lsignal, now - prev );
                PR_ADD( w, CTR_lsteal, now - prev );
            }
            break;

            // Done
        case 9 :
            if( w->level /* level */ == 0 ) {
                PR_ADD( w, CTR_init, now - prev );
            } else {
                PR_ADD( w, CTR_close, now - prev );
            }
            break;

        default: return;
    }

    w->time = now;
}
#else
#define lace_time_event( w, e ) /* Empty */
#endif

static Worker* __attribute__((noinline))
lace_steal(WorkerP *self, Task *__dq_head, Worker *victim)
{
    if (victim != NULL && !victim->allstolen) {
        TailSplitNA ts;
        ts.v = victim->ts.v;
        if (ts.ts.tail < ts.ts.split) {
            TailSplitNA ts_new;
            ts_new.v = ts.v;
            ts_new.ts.tail++;
            if (atomic_compare_exchange_weak(&victim->ts.v, &ts.v, ts_new.v)) {
                // Stolen
                Task *t = &victim->dq[ts.ts.tail];
                atomic_store_explicit(&t->thief, self->_public, memory_order_relaxed);
                lace_time_event(self, 1);
                t->f(self, __dq_head, t);
                lace_time_event(self, 2);
                atomic_store_explicit(&t->thief, THIEF_COMPLETED, memory_order_release);
                lace_time_event(self, 8);
                return LACE_STOLEN;
            }

            lace_time_event(self, 7);
            return LACE_BUSY;
        }

        if (victim->movesplit == 0) {
            victim->movesplit = 1;
            PR_COUNTSPLITS(self, CTR_split_req);
        }
    }

    lace_time_event(self, 7);
    return LACE_NOWORK;
}

static int
lace_shrink_shared(WorkerP *w)
{
    Worker *wt = w->_public;
    TailSplitNA ts; /* Use non-atomic version to emit better code */
    ts.v = wt->ts.v; /* Force in 1 memory read */
    uint32_t tail = ts.ts.tail;
    uint32_t split = ts.ts.split;

    if (tail != split) {
        uint32_t newsplit = (tail + split)/2;
        atomic_store_explicit(&wt->ts.ts.split, newsplit, memory_order_relaxed); /* emit normal write */
        atomic_thread_fence(memory_order_seq_cst);
        tail = wt->ts.ts.tail;
        if (tail != split) {
            if (unlikely(tail > newsplit)) {
                newsplit = (tail + split) / 2;
                atomic_store_explicit(&wt->ts.ts.split, newsplit, memory_order_relaxed); /* emit normal write */
            }
            w->split = w->dq + newsplit;
            PR_COUNTSPLITS(w, CTR_split_shrink);
            return 0;
        }
    }

    wt->allstolen = 1;
    w->allstolen = 1;
    return 1;
}

static inline void
lace_leapfrog(WorkerP *__lace_worker, Task *__lace_dq_head)
{
    lace_time_event(__lace_worker, 3);
    Task *t = __lace_dq_head;
    Worker *thief = t->thief;
    if (thief != THIEF_COMPLETED) {
        while ((size_t)thief <= 1) thief = t->thief;

        /* PRE-LEAP: increase head again */
        __lace_dq_head += 1;

        /* Now leapfrog */
        int attempts = 32;
        while (thief != THIEF_COMPLETED) {
            PR_COUNTSTEALS(__lace_worker, CTR_leap_tries);
            Worker *res = lace_steal(__lace_worker, __lace_dq_head, thief);
            if (res == LACE_NOWORK) {
                YIELD_NEWFRAME();
                if ((LACE_LEAP_RANDOM) && (--attempts == 0)) { lace_steal_random(); attempts = 32; }
            } else if (res == LACE_STOLEN) {
                PR_COUNTSTEALS(__lace_worker, CTR_leaps);
            } else if (res == LACE_BUSY) {
                PR_COUNTSTEALS(__lace_worker, CTR_leap_busy);
            }
            atomic_thread_fence(memory_order_acquire);
            thief = t->thief;
        }

        /* POST-LEAP: really pop the finished task */
        /*            no need to decrease __lace_dq_head, since it is a local variable */
        atomic_thread_fence(memory_order_acquire);
        /*compiler_barrier();*/
        if (__lace_worker->allstolen == 0) {
            /* Assume: tail = split = head (pre-pop) */
            /* Now we do a 'real pop' ergo either decrease tail,split,head or declare allstolen */
            Worker *wt = __lace_worker->_public;
            wt->allstolen = 1;
            __lace_worker->allstolen = 1;
        }
    }

    /*compiler_barrier();*/
    atomic_thread_fence(memory_order_acquire);
    atomic_store_explicit(&t->thief, THIEF_EMPTY, memory_order_relaxed);
    lace_time_event(__lace_worker, 4);
}

static __attribute__((noinline))
void lace_drop_slow(WorkerP *w, Task *__dq_head)
{
    if ((w->allstolen) || (w->split > __dq_head && lace_shrink_shared(w))) lace_leapfrog(w, __dq_head);
}

static inline __attribute__((unused))
void lace_drop(WorkerP *w, Task *__dq_head)
{
    if (likely(0 == w->_public->movesplit)) {
        if (likely(w->split <= __dq_head)) {
            return;
        }
    }
    lace_drop_slow(w, __dq_head);
}

'
#
# Create macros for each arity
#

for(( r = 0; r <= $k; r++ )) do

# Extend various argument lists
if ((r)); then
  MACRO_ARGS="$MACRO_ARGS, ATYPE_$r, ARG_$r"
  DECL_ARGS="$DECL_ARGS, ATYPE_$r"
  TASK_FIELDS="$TASK_FIELDS ATYPE_$r arg_$r;"
  TASK_INIT="$TASK_INIT t->d.args.arg_$r = arg_$r;"
  TASK_GET_FROM_t="$TASK_GET_FROM_t, t->d.args.arg_$r"
  CALL_ARGS="$CALL_ARGS, arg_$r"
  FUN_ARGS="$FUN_ARGS, ATYPE_$r arg_$r"
  WORK_ARGS="$WORK_ARGS, ATYPE_$r ARG_$r"
  ARGS_STRUCT="struct { $TASK_FIELDS } args;"
fi

FUN_ARGS_NC=${FUN_ARGS:2}

echo
echo "// Task macros for tasks of arity $r"
echo

# Create a void and a non-void version
for isvoid in 0 1; do
if (( isvoid==0 )); then
  DEF_MACRO="#define TASK_$r(RTYPE, NAME$MACRO_ARGS) \
             TASK_DECL_$r(RTYPE, NAME$DECL_ARGS) TASK_IMPL_$r(RTYPE, NAME$MACRO_ARGS)"
  DECL_MACRO="#define TASK_DECL_$r(RTYPE, NAME$DECL_ARGS)"
  IMPL_MACRO="#define TASK_IMPL_$r(RTYPE, NAME$MACRO_ARGS)"
  RTYPE="RTYPE"
  RES_FIELD="$RTYPE res;"
  SAVE_RVAL="t->d.res ="
  RETURN_RES="((TD_##NAME *)t)->d.res"
  UNION="union { $ARGS_STRUCT $RTYPE res; } d;"
  SS_RETURN="return "
  SS_RETURN2=""
else
  DEF_MACRO="#define VOID_TASK_$r(NAME$MACRO_ARGS) \
             VOID_TASK_DECL_$r(NAME$DECL_ARGS) VOID_TASK_IMPL_$r(NAME$MACRO_ARGS)"
  DECL_MACRO="#define VOID_TASK_DECL_$r(NAME$DECL_ARGS)"
  IMPL_MACRO="#define VOID_TASK_IMPL_$r(NAME$MACRO_ARGS)"
  RTYPE="void"
  SAVE_RVAL=""
  RETURN_RES=""
  if ((r)); then UNION="union { $ARGS_STRUCT } d;"; else UNION=""; fi
  SS_RETURN=""
  SS_RETURN2="return;"
fi

# Write down the macro for the task declaration
(\
echo "$DECL_MACRO

typedef struct _TD_##NAME {
  TASK_COMMON_FIELDS(_TD_##NAME)
  $UNION
} TD_##NAME;

static_assert(sizeof(TD_##NAME) <= sizeof(Task), \"TD_\" #NAME \" is too large, set LACE_TASKSIZE to a higher value!\");

void NAME##_WRAP(WorkerP *, Task *, TD_##NAME *);
$RTYPE NAME##_CALL(WorkerP *, Task * $FUN_ARGS);
static inline $RTYPE NAME##_SYNC(WorkerP *, Task *);
static $RTYPE NAME##_SYNC_SLOW(WorkerP *, Task *);

static inline __attribute__((unused))
void NAME##_SPAWN(WorkerP *w, Task *__dq_head $FUN_ARGS)
{
    PR_COUNTTASK(w);

    TD_##NAME *t;
    TailSplitNA ts;
    uint32_t head, split, newsplit;

    if (__dq_head == w->end) lace_abort_stack_overflow();

    t = (TD_##NAME *)__dq_head;
    t->f = &NAME##_WRAP;
    atomic_store_explicit(&t->thief, THIEF_TASK, memory_order_relaxed);
    $TASK_INIT
    /*compiler_barrier();*/
    atomic_thread_fence(memory_order_acquire);

    Worker *wt = w->_public;
    if (unlikely(w->allstolen)) {
        if (wt->movesplit) wt->movesplit = 0;
        head = __dq_head - w->dq;
        ts = (TailSplitNA){{head,head+1}};
        wt->ts.v = ts.v;
        /*compiler_barrier();*/
        wt->allstolen = 0;
        w->split = __dq_head+1;
        w->allstolen = 0;
    } else if (unlikely(wt->movesplit)) {
        head = __dq_head - w->dq;
        split = w->split - w->dq;
        newsplit = (split + head + 2)/2;
        wt->ts.ts.split = newsplit;
        w->split = w->dq + newsplit;
        /*compiler_barrier();*/
        wt->movesplit = 0;
        PR_COUNTSPLITS(w, CTR_split_grow);
    }
}

static inline __attribute__((unused))
$RTYPE NAME##_NEWFRAME($FUN_ARGS_NC)
{
    Task _t;
    TD_##NAME *t = (TD_##NAME *)&_t;
    t->f = &NAME##_WRAP;
    atomic_store_explicit(&t->thief, THIEF_TASK, memory_order_relaxed);
    $TASK_INIT
    lace_run_newframe(&_t);
    return $RETURN_RES;
}

static inline __attribute__((unused))
void NAME##_TOGETHER($FUN_ARGS_NC)
{
    Task _t;
    TD_##NAME *t = (TD_##NAME *)&_t;
    t->f = &NAME##_WRAP;
    atomic_store_explicit(&t->thief, THIEF_TASK, memory_order_relaxed);
    $TASK_INIT
    lace_run_together(&_t);
}

static inline __attribute__((unused))
$RTYPE NAME##_RUN($FUN_ARGS_NC)
{
    Task _t;
    TD_##NAME *t = (TD_##NAME *)&_t;
    t->f = &NAME##_WRAP;
    atomic_store_explicit(&t->thief, THIEF_TASK, memory_order_relaxed);
    $TASK_INIT
    lace_run_task(&_t);
    return $RETURN_RES;
}

static inline __attribute__((unused))
$RTYPE NAME##_RUNEX($FUN_ARGS_NC)
{
    Task _t;
    TD_##NAME *t = (TD_##NAME *)&_t;
    t->f = &NAME##_WRAP;
    atomic_store_explicit(&t->thief, THIEF_TASK, memory_order_relaxed);
    $TASK_INIT
    lace_run_task_exclusive(&_t);
    return $RETURN_RES;
}

static __attribute__((noinline))
$RTYPE NAME##_SYNC_SLOW(WorkerP *w, Task *__dq_head)
{
    TD_##NAME *t;

    if ((w->allstolen) || (w->split > __dq_head && lace_shrink_shared(w))) {
        lace_leapfrog(w, __dq_head);
        t = (TD_##NAME *)__dq_head;
        return $RETURN_RES;
    }

    /*compiler_barrier();*/

    Worker *wt = w->_public;
    if (wt->movesplit) {
        Task *t = w->split;
        size_t diff = __dq_head - t;
        diff = (diff + 1) / 2;
        w->split = t + diff;
        wt->ts.ts.split += diff;
        /*compiler_barrier();*/
        wt->movesplit = 0;
        PR_COUNTSPLITS(w, CTR_split_grow);
    }

    /*compiler_barrier();*/

    t = (TD_##NAME *)__dq_head;
    atomic_store_explicit(&t->thief, THIEF_EMPTY, memory_order_relaxed);
    ${SS_RETURN}NAME##_CALL(w, __dq_head $TASK_GET_FROM_t);
}

static inline __attribute__((unused))
$RTYPE NAME##_SYNC(WorkerP *w, Task *__dq_head)
{
    /* assert (__dq_head > 0); */  /* Commented out because we assume contract */

    if (likely(0 == w->_public->movesplit)) {
        if (likely(w->split <= __dq_head)) {
            TD_##NAME *t = (TD_##NAME *)__dq_head;
            atomic_store_explicit(&t->thief, THIEF_EMPTY, memory_order_relaxed);
            ${SS_RETURN}NAME##_CALL(w, __dq_head $TASK_GET_FROM_t);
            ${SS_RETURN2}
        }
    }

    ${SS_RETURN}NAME##_SYNC_SLOW(w, __dq_head);
}

"\
) | awk '{printf "%-86s\\\n", $0 }'

echo ""

(\
echo "$IMPL_MACRO
void NAME##_WRAP(WorkerP *w, Task *__dq_head, TD_##NAME *t __attribute__((unused)))
{
    $SAVE_RVAL NAME##_CALL(w, __dq_head $TASK_GET_FROM_t);
}

static inline __attribute__((always_inline))
$RTYPE NAME##_WORK(WorkerP *__lace_worker, Task *__lace_dq_head $DECL_ARGS);

/* NAME##_WORK is inlined in NAME##_CALL and the parameter __lace_in_task will disappear */
$RTYPE NAME##_CALL(WorkerP *w, Task *__dq_head $FUN_ARGS)
{
    ${SS_RETURN}NAME##_WORK(w, __dq_head $CALL_ARGS);
}

static inline __attribute__((always_inline))
$RTYPE NAME##_WORK(WorkerP *__lace_worker __attribute__((unused)), Task *__lace_dq_head __attribute__((unused)) $WORK_ARGS)" \
) | awk '{printf "%-86s\\\n", $0 }'

echo ""

echo $DEF_MACRO

echo ""

done

done

echo "

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif"
