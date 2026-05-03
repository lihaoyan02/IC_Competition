/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/
#include <common.h>

uint32_t expr(char *e, bool *success);

#define NR_WP 32

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;

	char e_str[32];
	uint32_t pre_result;
  /* TODO: Add more members if necessary */

} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

/* TODO: Implement the functionality of watchpoint */

static WP* new_wp(char *e) {
	if (free_ == NULL) {
		printf("no free watch point\n");
		assert(0);
		return NULL;
	}
	if(strlen(e)>31) {
		printf("expression is too long\n");
		return NULL;
	}
	bool success=true;
	uint32_t expr_result = expr(e, &success);
	if(success) {
		WP* new_watchpoint = free_;
		free_ = free_->next;
		new_watchpoint->next = NULL;

		if (head == NULL) {
			head = new_watchpoint;
			new_watchpoint->NO = 1;
		} else {
			new_watchpoint->next = head;
			head = new_watchpoint;
			new_watchpoint->NO = new_watchpoint->next->NO + 1;
		}
	
		strcpy(new_watchpoint->e_str, e);
		new_watchpoint->pre_result = expr_result;
		return new_watchpoint;

	} else {
		return NULL;
	}
}

static void free_wp(WP *wp) {
	if (wp == NULL) {
		assert(0);
		return;
	}
	if (head == wp) {
		head = wp->next;
	} else {
		for(WP* current = head; current != NULL; current = current->next) {
			if (current == NULL) {
				printf("no such wp to be free\n");
				assert(0);
			}
			if (current->next == wp) {
				current->next = wp->next;
			}
		}
	}
	wp->next = free_;
	free_ = wp;
}

bool scan_wp_diff() {
	for(WP* current = head; current != NULL; current = current->next) {
		bool success=true;
		uint32_t new_result = expr(current->e_str, &success);
		assert(success==true);
		if (current->pre_result != new_result) {
			current->pre_result = new_result; 
			printf("watchpoint [%d] triggerd\n", current->NO);
			return true;
		}
	}
	return false;
}

void set_new_wp(char *e) {
	WP* new_watchpoint = new_wp(e);
	if(new_watchpoint != NULL) {
		printf("watchpoint [%d] set successfully\n", new_watchpoint->NO);
	} else {
		printf("watchpoint set fail\n");
	}
}

void delete_wp(int N) {
	for(WP* current = head; current != NULL; current = current->next) {
		if (current->NO == N) {
			free_wp(current);
			printf("watchpoint [%d] deleted successfully\n", N);
			return;
		}
	}
	printf("no such watchpoint\n");
}

void print_wp_info() {
	if( head == NULL) {
		printf("NO watchpoint\n");
	}
	for(WP* current = head; current != NULL; current = current->next) {
		printf("[%d] : %s = %u (0x%x)\n", current->NO, current->e_str, current->pre_result, current->pre_result);
	}
}
