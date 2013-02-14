/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-02-12: Initial release

    Authors:        Gavin Norman

    Functions to set a process' CPU affinity.

*******************************************************************************/

module ocean.sys.CpuAffinity;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.stdc.posix.sys.types : pid_t;



/*******************************************************************************

    Definition of external functions required to set cpu affinity.

*******************************************************************************/

private extern ( C )
{
    /* Type for array elements in 'cpu_set_t'.  */
    typedef uint __cpu_mask;

    /* Size definition for CPU sets.  */
    const __CPU_SETSIZE = 1024;
    const __NCPUBITS = (8 * __cpu_mask.sizeof);

    /* Data structure to describe CPU mask.  */
    struct cpu_set_t
    {
        __cpu_mask[__CPU_SETSIZE / __NCPUBITS] __bits;
    }

    int sched_setaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *mask);
}



/*******************************************************************************

    Struct containing static functions for cpu affinity.

*******************************************************************************/

public struct CpuAffinity
{
static:

    /***************************************************************************

        Sets the CPU affinity of the calling process.

        Params:
            cpu = index of cpu to run process on

        Returns:
            true on success, false on failure (errno will be set)

    ***************************************************************************/

    public bool set ( uint cpu )
    {
        cpu_set_t cpu_set;
        CPU_SET(cast(__cpu_mask)cpu, cpu_set);

        const pid_t pid = 0; // 0 := calling process
        auto ret = sched_setaffinity(pid, cpu_set_t.sizeof, &cpu_set);
        return ret == 0;
    }


    // TODO: multiple CPU affinity setter (if needed)


    /***************************************************************************

        CPU index bit mask array index. Converted from the __CPUELT macro
        defined in bits/sched.h:

        ---

            # define __CPUELT(cpu)    ((cpu) / __NCPUBITS)

        ---

        Params:
            cpu = cpu index

        Returns:
            index of bit mask array element which the indexed cpu is within

    ***************************************************************************/

    private size_t CPUELT ( uint cpu )
    {
        return (cpu / __NCPUBITS);
    }


    /***************************************************************************

        CPU index bit mask. Converted from the __CPUMASK macro defined in
        bits/sched.h:

        ---

            # define __CPUMASK(cpu) ((__cpu_mask) 1 << ((cpu) % __NCPUBITS))

        ---

        Params:
            cpu = cpu index

        Returns:
            bit mask with the indexed cpu set to 1

    ***************************************************************************/

    private __cpu_mask CPUMASK ( uint cpu )
    {
        return cast(__cpu_mask)(1 << (cpu % __NCPUBITS));
    }


    /***************************************************************************

        Sets the bit mask of the provided cpu_set_t to the indexed cpu.
        Converted from the __CPU_SET macro defined in bits/sched.h:

        ---

            # define __CPU_SET(cpu, cpusetp) \
              ((cpusetp)->__bits[__CPUELT (cpu)] |= __CPUMASK (cpu))

        ---

        Params:
            cpu = cpu index
            set = cpu set

        Returns:
            cpu set with bit mask with the indexed cpu set to 1

    ***************************************************************************/

    private void CPU_SET ( uint cpu, ref cpu_set_t set )
    {
        set.__bits[CPUELT(cpu)] |= CPUMASK(cpu);
    }
}

