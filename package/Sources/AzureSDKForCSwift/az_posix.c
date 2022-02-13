// Copyright (c) Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

#include "az_platform.h"
#include "az_config_internal.h"
#include "az_precondition_internal.h"

#include <time.h>

#include <unistd.h>

#include "_az_cfg.h"

AZ_NODISCARD az_result az_platform_clock_msec(int64_t* out_clock_msec)
{
  _az_PRECONDITION_NOT_NULL(out_clock_msec);

  // NOLINTNEXTLINE(bugprone-misplaced-widening-cast)
  *out_clock_msec = (int64_t)((clock() / CLOCKS_PER_SEC) * _az_TIME_MILLISECONDS_PER_SECOND);

  return AZ_OK;
}

AZ_NODISCARD az_result az_platform_sleep_msec(int32_t milliseconds)
{
  (void)usleep((useconds_t)milliseconds * _az_TIME_MICROSECONDS_PER_MILLISECOND);
  return AZ_OK;
}
