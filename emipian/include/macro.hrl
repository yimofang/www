-define(APPOS_IOS, 1).
-define(APPOS_ANDROID, 3).
-define(APPOS_WINPHONE,4).

-define(APPMOBILE_MAX,8).

-define(APPOS_PC,11).
-define(APPOS_ADMIN,12).

-define(APPCODE_EMIPIAN, 1).
-define(APPCODE_MICHAT,  2).
-define(SYSTEMID,  <<"systemid">>).
-define(EMIPIANIDTEAM,  <<"systemid">>).

%% session status
-define(STATUS_ONLINE,  0).
-define(STATUS_OFFLINE,  1).
-define(STATUS_LOGINING,  9).
-define(STATUS_DISCONNECTED,  10).

-define(STATUS_DELETED,  20).

%% chat status
-define(CHATSTATUS_NOT_SEND,  0).
-define(CHATSTATUS_SENDED,  1).
-define(CHATSTATUS_SELF,  2).
-define(CHATSTATUS_ONLY_REC,  3).
-define(CHATSTATUS_CANCEL,  10).

-define(CHATSTATUS_CMDERROR,  20).

%% chat type
-define(CHATSTYPE_SINGLE,  0).
-define(CHATSTYPE_GROUP,  1).
-define(CHATSTYPE_FIXGROUP,  2).
-define(CHATSTYPE_ALL,  3).
-define(CHATSTYPE_DIRECT,  4).
-define(CHATSTYPE_DIRECTREPLY,  5).
-define(CHATSTYPE_MAX_LOGIN_SEND,  10).

-define(CHATSTYPE_CHATROOM,  101).


-define(APNS_MAXLEN,  20).

-define(DAIL_STATUS_INIT,  30).
-define(DAIL_STATUS_SENDING,  31).
-define(DAIL_STATUS_SENDED,  32).


-define(DAIL_STATUS_EXCEPOTION,  19).
-define(DAIL_STATUS_HANGOFF,  18).

-define(HANG_STATUS_SUCESS,  0). %%
-define(HANG_STATUS_BZX,     1).  %% off line
-define(HANG_STATUS_ZX,      2).  
-define(HANG_STATUS_QX,  3).
-define(HANG_STATUS_JJ,  4).
-define(HANG_STATUS_CS,  5). %%time out 
-define(HANG_STATUS_MEETERROR,  10).

-define(HANG_STATUS_BQW,  11).
-define(HANG_STATUS_COMPLETE,  12).
