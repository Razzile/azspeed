#include <sys/time.h>
#include <time.h>
#include <mach/mach.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <mach/mach_time.h>


int (*old_gettimeofday)(struct timeval *tv, struct timezone *tz);
time_t (*old_time)(time_t *timer);
uint64_t (*old_mach_absolute_time)();
void (*old_mach_timebase_info)(mach_timebase_info_data_t info);

__attribute__((always_inline))
inline bool IsCallFromMainExecutable()
{
	int lr = 0;
	asm volatile("mov %0, lr" : "=r"(lr));

	vm_address_t address = 0x0;
	kern_return_t status = KERN_SUCCESS;
	vm_size_t vmsize;

	vm_region_basic_info_data_t info;
	mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT;
	memory_object_name_t object;

	status = vm_region(mach_task_self(), &address, &vmsize, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &info_count, &object);

	if(status == KERN_SUCCESS) //to do: check objc classes lie in read/write regions (will reduce memory search time)
		{
			if(address < lr && address+vmsize > lr)
				{
					return true;
				}
			}
			return false;
}

int new_gettimeofday(struct timeval *tv, struct timezone *tz)
{
	if(IsCallFromMainExecutable())
	{
		int ret = old_gettimeofday(tv, tz);
		tv->tv_sec = tv->tv_sec * 4;
		tv->tv_usec = tv->tv_usec * 4;
		return ret;
	}
	return old_gettimeofday(tv, tz);
}

time_t new_time(time_t *timerPtr)
{
	if(IsCallFromMainExecutable())
	{
		time_t timer = old_time(timerPtr);
		timer = timer * 4;
		if (timerPtr != NULL) *timerPtr = timer;
		return timer;
	}
	return old_time(timerPtr);
}

uint64_t new_mach_absolute_time()
{
	if(IsCallFromMainExecutable())
	{
		return old_mach_absolute_time() * 4;
	}
	return old_mach_absolute_time();
}

void new_mach_timebase_info(mach_timebase_info_data_t info)
{
	if(IsCallFromMainExecutable())
	{
		old_mach_timebase_info(info);
		info.numer *= 4;
		return;
	}
	return old_mach_timebase_info(info);
}

%ctor
{
	if(strstr(_dyld_get_image_name(0), "/var/mobile/") != NULL)
	{

		MSHookFunction((void*)gettimeofday, (void*)new_gettimeofday, (void**)&old_gettimeofday);
		 MSHookFunction((void*)time, (void*)new_time, (void**)&old_time);
		// MSHookFunction((void*)mach_absolute_time, (void*)new_mach_absolute_time, (void**)&old_mach_absolute_time);
		// MSHookFunction((void*)mach_timebase_info, (void*)new_mach_timebase_info, (void**)&old_mach_timebase_info);
	}
}
