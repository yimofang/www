%% @author hyf
%% @doc @todo Add description to emipian_meet.


-module(emipian_meet).

%% ====================================================================
%% API functions
%% ====================================================================
-export([createMeeting/2,get_meeting/1,createMeeting/0]).

%% ====================================================================
%% Internal functions
%% ====================================================================

createMeeting({OrgRegname,OrgAdminUsername,HostUsername,HostPassword,
           HostNickname,AppkeyPass},{MaxUser,MeetingName})->

  TimeStamp = emipian_util:get_curtimestamp(),
  STimeStamp =integer_to_list(TimeStamp,10), 
%%  OrgRegname ="jiankangtai",	
%%  OrgAdminUsername ="admin",
%%  HostUsername  ="emiage",
%%  HostPassword  ="123456",
%%  HostNickname  ="emipian",
%%  AppkeyPass ="123456",
%%  MaxUser  = "3",
%%  MeetingName ="test123",
  
  {{Year,Mon,Day},{H,M,S}} = calendar:now_to_local_time(erlang:now()),

  StartTime =integer_to_list(Year,10)++"-"++integer_to_list(Mon,10)++"-"++integer_to_list(Day,10)++" "++
        integer_to_list(H,10)++":"++integer_to_list(M,10)++":"++integer_to_list(S,10),
  EndTime =integer_to_list(Year,10)++"-"++integer_to_list(Mon,10)++"-"++integer_to_list(Day,10)++" "++
        integer_to_list(H+23,10)++":"++integer_to_list(M,10)++":"++integer_to_list(S,10),
  
   SignData =AppkeyPass++"endTime"++EndTime++"hostNickname"++HostNickname++"hostPassword"++HostPassword
            ++"hostUsername"++HostUsername++"maxUser"++integer_to_list(MaxUser,10)++"meetingName"++MeetingName
            ++"orgAdminUsername"++OrgAdminUsername++"orgRegname"++OrgRegname
            ++"startTime"++StartTime++"timestamp"++STimeStamp,
  SignData1 = http_uri:encode(SignData),
  SignData2 = list_to_binary(SignData1),
  SignData3 = binary:replace(SignData2, <<"%20">>, <<"+">>,[global] ),
  SignData4 = binary_to_list(SignData3),
 
  Context = erlang:md5_init(),
  Context1 =  erlang:md5_update(Context, (SignData4)),
  
  Md50 = erlang:md5_final(Context1),	
  Md5heX = emipian_util:list_to_hex(binary_to_list(Md50)),
  Md5heX0 = string:to_upper(Md5heX),
%%  http_uri:encode
	
  Url = "http://is.liveuc.net/api/org/meeting/edit?"++"timestamp="++STimeStamp++"&sign="++Md5heX0
        ++"&endTime="++http_uri:encode(EndTime)
        ++"&hostNickname="++http_uri:encode(HostNickname)
        ++"&hostPassword="++HostPassword
        ++"&hostUsername="++HostUsername
        ++"&maxUser="++integer_to_list(MaxUser,10)
        ++"&meetingName="++http_uri:encode(MeetingName)
        ++"&orgAdminUsername="++OrgAdminUsername
        ++"&orgRegname="++OrgRegname
	    ++"&startTime="++http_uri:encode(StartTime),
       
 Result = httpc:request(post, {Url, [],"",""}, [{version, "HTTP/1.1"}], [], httpc:default_profile()),
 case Result of
  {error,_} ->fail;
  {ok,{_,_,Body}} ->
	  case rfc4627:decode(Body) of
		  {ok,Data1,_} -> 
				RetCode =case  rfc4627:get_field(Data1, "ret") of
					          {ok,Ret} ->Ret;
					         _->fail
				          end, 
                 if RetCode=:=0 ->
 				     PassWord = case  rfc4627:get_field(Data1, "meetingPassword") of
	 							    {ok,Pass} ->Pass;
								    _->fail
						        end,
	
				     MeetingID = case  rfc4627:get_field(Data1,"meetingId") of
 					               {ok,MeetingID0} ->MeetingID0;
					            _->fail
				                end,
                     {MeetingID,PassWord};
                    true->fail
                  end; 
		      _-> fail
        end
  end.




validate_cfg(L) ->L.

get_meeting(Param)->
    case emipian_config:get_option(meeting,fun validate_cfg/1) of
 	  undefined ->
	    not_found;
	   Ls ->
		 case lists:keysearch(Param, 1, Ls) of
			false->

            not_found;

			{value,{_,Value}}->
           Value
	  end
    end.


createMeeting()-> 
  OrgRegname =   binary_to_list(get_meeting(orgregname)),
  OrgAdminUsername = binary_to_list(get_meeting(orgadminusername)),
  HostUsername = binary_to_list(get_meeting(hostusername)),
  HostPassword = binary_to_list(get_meeting(hostpassword)),
  HostNickname = binary_to_list(get_meeting(hostnickname)),
  AppkeyPass = binary_to_list(get_meeting(appkeypass)),
  createMeeting({OrgRegname,OrgAdminUsername,HostUsername,HostPassword,
           HostNickname,AppkeyPass},{3,"emipian"}).


