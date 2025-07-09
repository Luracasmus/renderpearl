layout(std430, binding = 3) restrict buffer indirectDispatch {
	uvec3 work_groups;
} indirect_dispatch;
