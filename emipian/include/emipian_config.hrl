-record(local_config, {key :: any(), value :: any()}).

-type local_config() :: #local_config{}.

-record(state,
	{opts = []               :: [acl:acl() | local_config()],
         hosts = []              :: [binary()],
         override_local = false  :: boolean(),
	 override_global = false :: boolean(),
         override_acls = false   :: boolean()}).
