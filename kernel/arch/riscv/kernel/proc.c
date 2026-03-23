#include <mm.h>
#include <proc.h>
#include <printk.h>
#include <stdlib.h>
#include <private_kdefs.h>

static struct task_struct *task[NR_TASKS]; // 线程数组，所有的线程都保存在此
static struct task_struct *idle;           // idle 线程
struct task_struct *current;               // 当前运行线程

void __dummy(void);
void __switch_to(struct task_struct *prev, struct task_struct *next);

// 在这里添加或实现这些函数：
// - void dummy_task(void);
// - void task_init(void);
// - void do_timer(void);
// - void schedule(void);
// - void switch_to(struct task_struct* next);
// #error Not yet implemented

void dummy_task(void) {
    // printk("[PID = %" PRIu64 "] Dummy task started.\n", current->pid);
  unsigned local = 0;
  unsigned prev_cnt = 0;
  while (1) {
    if (current->counter != prev_cnt) {
      if (current->counter == 1) {
        // 若 priority 为 1，则线程可见的 counter 永远为 1（为什么？）
        // 通过设置 counter 为 0，避免信息无法打印的问题
        current->counter = 0;
      }
      prev_cnt = current->counter;
      printk("[PID=%" PRIu64 "]=%u\n", current->pid, ++local);
    }
  }
}
void task_init(void) {
    srand(2025);

    /* 1-3: init idle (task[0]) */
    void *pg = alloc_page();
    idle = (struct task_struct *)pg;
    idle->state = TASK_RUNNING;
    idle->pid = 0;
    idle->priority = 0;
    idle->counter = 0;
    task[0] = idle;
    current = idle;

    /* 4: init other tasks */
    for (int i = 1; i < NR_TASKS; ++i) {
        void *p = alloc_page();
        task[i] = (struct task_struct *)p;
        task[i]->state = TASK_RUNNING;
        task[i]->pid = i;
        task[i]->priority = PRIORITY_MIN + (rand() % (PRIORITY_MAX - PRIORITY_MIN + 1));
        task[i]->counter = 0;
        task[i]->thread.ra = (unsigned long)__dummy;
        task[i]->thread.sp = (unsigned long)p + PGSIZE;
    }

    printk("...task_init done!\n");
}
void do_timer(void) {
    // printk("[Timer] Tick! PID = %" PRIu64 ", Counter = %d\n", current->pid, current->counter);
    if (current->counter == 0) {
        // Time slice exhausted, perform scheduling
        schedule();
    } else {
        // Decrease remaining time
        current->counter--;
        if (current->counter == 0) {
            // If remaining time is 0, perform scheduling
            schedule();
        }
    }
}

void schedule(void) {
    for (;;) {
        int next_idx = -1;
        int max_counter = -1;

        /* find runnable task with largest counter */
        for (int i = 0; i < NR_TASKS; ++i) {
            struct task_struct *t = task[i];
            if (!t) continue;
            if (t->state != TASK_RUNNING) continue;
            if ((int)t->counter > max_counter) {
                max_counter = t->counter;
                next_idx = i;
            }
        }

        if (max_counter > 0 && next_idx >= 0) {
            switch_to(task[next_idx]);
            return;
        }

        /* all counters are 0 -> reload from priority and retry */
        for (int i = 0; i < NR_TASKS; ++i) {
            struct task_struct *t = task[i];
            if (!t) continue;
            t->counter = t->priority;
        }
    }
}


void switch_to(struct task_struct *next) {
    struct task_struct *prev = current;
    if (prev == next) {
        return;
    }
    current = next;
    printk("[Switch] %" PRIu64 " -> %" PRIu64 "\n", prev->pid, next->pid);
    __switch_to(prev, next);
}