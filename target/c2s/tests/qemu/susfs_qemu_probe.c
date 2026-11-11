// SPDX-License-Identifier: GPL-2.0
/* Test-only control points for exercising real SUSFS hooks without Android's
 * manager/policy bootstrap. This file is NEVER linked into the phone build.
 * Changing the creator-domain SID is synthetic setup, not an Android root test.
 */
#include <linux/moduleparam.h>
#include <linux/kernel.h>
#include <linux/susfs_def.h>

extern bool susfs_hide_sus_mnts_for_non_su_procs;
extern u32 susfs_ksu_sid;
extern u32 susfs_get_current_sid(void);

module_param_named(global_hiding, susfs_hide_sus_mnts_for_non_su_procs, bool, 0600);

static int creator_set(const char *value, const struct kernel_param *kp)
{
	bool enabled;
	int ret = kstrtobool(value, &enabled);
	(void)kp;
	if (ret)
		return ret;
	susfs_ksu_sid = enabled ? susfs_get_current_sid() : 0;
	return 0;
}
static const struct kernel_param_ops creator_ops = {
	.set = creator_set,
	.get = param_get_uint,
};
module_param_cb(creator_domain, &creator_ops, &susfs_ksu_sid, 0600);

static int container_get(char *buffer, const struct kernel_param *kp)
{
	(void)kp;
	return scnprintf(buffer, PAGE_SIZE, "%d\n", susfs_is_current_in_container());
}
static const struct kernel_param_ops container_ops = { .get = container_get };
module_param_cb(in_container, &container_ops, NULL, 0400);

static int flag_set(const char *value, const struct kernel_param *kp)
{
	bool enabled;
	int ret = kstrtobool(value, &enabled);
	(void)kp;
	if (ret)
		return ret;
	if (enabled)
		set_thread_flag(TIF_PROC_UMOUNTED);
	else
		clear_thread_flag(TIF_PROC_UMOUNTED);
	return 0;
}
static const struct kernel_param_ops flag_ops = { .set = flag_set };
module_param_cb(unmounted_flag, &flag_ops, NULL, 0200);
