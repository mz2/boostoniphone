/*
 *  UsingBoost.cpp
 *  Boost
 *
 *  Created by Pete Goodliffe on 02/10/2010.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "UsingBoost.h"

#include <boost/signals.hpp>
#include <boost/bind.hpp>

#define MYASSERT(a) \
    if (!(a)) \
    { \
        fprintf(stderr, "%s:%u: Assertion failure: %s\n", __FILE__, __LINE__, #a);\
        abort(); \
    }

void Increment(unsigned &counter)
{
    counter++;
}

void UseSomeBoostStuffToProveItWorksOK()
{
    boost::signal<void()> signal;

    unsigned signalCounter = 0;
    MYASSERT(signalCounter == 0);

    signal();

    signal.connect(boost::bind(&Increment, boost::ref(signalCounter)));

    signal();

    MYASSERT(signalCounter == 1);
}

int main()
{
    fprintf(stderr, "Boost framework test program.\n");
    UseSomeBoostStuffToProveItWorksOK();
    return 0;
}
