-record( session,
		      {
			  sessionid =  <<"">> :: binary(),
			  randomcode = <<"">> :: binary(),
			  secret =	 <<"">> :: binary(), 
              lastactive=0::erlang:stamptime(),
              status=0 :: integer(), %% 0-online 1-offline 9-logining 10-disconnected 
              userid = <<"systemid">> :: binary(),
			  usertype = 0 ::integer(),
              appos =0 :: integer(),
              appcode=0 ::integer(),
              customcode =100 :: integer(),
              termialno = <<"">> :: binary(),
			  termialname = <<"">> :: binary(),
              lang =0  :: integer(),
			  logintime,
			  authcodetime,
			  secretnew =  <<"">> :: binary(),
              secretold =  <<"">> :: binary(), 
              version = <<"">> :: binary(),
			  peerip = <<"">> :: binary(),
			  s_peerip = <<"">> :: binary(), 
			  selfpid::pid(),
			  node::binary(),
			  pids,
			  mainlink = 0 :: integer(),
			  sessionextid = <<"">> :: binary()
}
).
-type session() :: #session{}.