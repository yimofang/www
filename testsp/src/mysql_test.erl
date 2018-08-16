%% file: mysql_test.erl
%% author: Yariv Sadan (yarivvv@gmail.com)
%% for license see COPYING

-module(mysql_test).
-compile(export_all).
-export([test/0,test1/0	]).

test() ->
 %%   compile:file("/usr/local/lib/erlang/lib/mysql/mysql.erl"),
 %%   compile:file("/usr/local/lib/erlang/lib/mysql/mysql_conn.erl"),
    
    %% Start the MySQL dispatcher and create the first connection
    %% to the database. 'p1' is the connection pool identifier.
    mysql:start_link(p1, "192.168.1.122", "root", "123456", "test"),

    %% Add 2 more connections to the connection pool
    mysql:connect(p1, "192.168.1.122", undefined, "root", "123456", "test",
		  true),
    mysql:connect(p1, "192.168.1.122", undefined, "root", "123456", "test",
		  true),
    
    mysql:fetch(p1, <<"DELETE FROM developer">>),

    mysql:fetch(p1, <<"INSERT INTO developer(name, country) VALUES "
		     "('Claes (Klacke) Wikstrom', 'Sweden'),"
		     "('Ulf Wiger', 'USA')">>),

    %% Execute a query (using a binary)
    Result1 = mysql:fetch(p1, <<"SELECT * FROM developer">>),
    io:format("Result1: ~p~n", [Result1]),
    
    %% Register a prepared statement
    mysql:prepare(update_developer_country,
		  <<"UPDATE developer SET country=? where name like ?">>),
    
    %% Execute the prepared statement
    mysql:execute(p1, update_developer_country, [<<"Sweden">>, <<"%Wiger">>]),
    
    Result2 = mysql:fetch(p1, <<"SELECT * FROM developer">>),
    io:format("Result2: ~p~n", [Result2]),
    
    mysql:transaction(
      p1,
      fun() -> mysql:fetch(<<"INSERT INTO developer(name, country) VALUES "
			    "('Joe Armstrong', 'USA')">>),
	       mysql:fetch(<<"DELETE FROM developer WHERE name like "
			    "'Claes%'">>)
      end),

    Result3 = mysql:fetch(p1, <<"SELECT * FROM developer">>),
    io:format("Result3: ~p~n", [Result3]),
    
    mysql:prepare(delete_all, <<"DELETE FROM developer">>),

    {error, foo} = mysql:transaction(
		     p1,
		     fun() -> mysql:execute(delete_all),
			      throw({error, foo})
		     end),

    Result4 = mysql:fetch(p1, <<"SELECT * FROM developer">>),
    io:format("Result4: ~p~n", [Result4]),
				    
    ok.


test1() ->

	P1 = mysql:start_link(["192.168.1.122",3306, "root", "123456", "MPe",undefined]),

    %% Add 2 more connections to the connection pool
 %%   mysql:connect(p1, "192.168.1.122", undefined, "root", "123456", "MPe",
%%		  true),
 %%   mysql:connect(p1, "192.168.1.122", undefined, "root", "123456", "MPe",
%%		  true),
    

    S1=str:concat(<<"CALL c_sp_GetFriends(">>,<<"\"EC672E45-9836-39E4-786D-3563579748A5\",0,0,@i)">>),
	%% ;SELECT @i
	Result3 = mysql:fetch(P1,binary_to_list(S1)),
	Curor = mysql_op:get_resultdata(Result3),
     Curor1=  mysql_op:firstrow(Curor),
     Index = mysql_op:get_fieldIndex(Curor,"fsUserID"),
     mysql_op:getfielddataAsStr(Curor1,Index). 

%%    mysql:get_result_rows(Data).
%%	Data.
%%	mysql_op:get_fieldIndex(Data,"fsUserID").
%%	Result3.
%%	[H|T] =Result3,
%%	{H1,T1} =H,

 %%   mysql:get_result_field_info(T1).	
  %%  mysql:get_result_rows(T1).	



%% io:format("~p~n", [Result3]).
