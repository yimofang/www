%% @author hyf
%% @doc @todo Add description to mysql_op.


-module(mysql_op).

%% ====================================================================
%% API functions
%% ====================================================================
-export([get_fieldIndex/2,get_resultdata/1,get_resultdata/2,getfielddata/2,firstrow/1,
         nextrow/1,prerow/1,getfielddataAsStr/2,getfielddataAsInt/2]).

-record(mysql_curor,
	{
     fieldinfo=[],
	 rows=[],
	 currowindex=0}).

%% ====================================================================
%% Internal functions
%% ====================================================================

get_resultdata(Result)
  ->
	get_resultdata(Result,1).


get_resultdata(Result,Index)
  ->
	Data = get_data(Result,1,Index),
	case Data of
	 not_found->not_found;
	 error->error;
	_->	
	   FieldInfos = mysql:get_result_field_info(Data),
	  Rows = mysql:get_result_rows(Data),
	  #mysql_curor{fieldinfo = FieldInfos,rows=Rows}
  end.

getfielddata(Curor,FieldIndex)->
    #mysql_curor{rows=Rows,currowindex =CurRowIndex} = Curor,
    RowInfo = lists:nth(CurRowIndex, Rows), 
    FieldData =   lists:nth(FieldIndex, RowInfo),  
    FieldData.
  
getfielddataAsStr(Curor,FieldIndex)->
   list_to_binary(getfielddata(Curor,FieldIndex)).

getfielddataAsInt(Curor,FieldIndex)->
   Data = getfielddata(Curor,FieldIndex),
   {I,_}=string:to_integer(Data),
   I.

firstrow(Curor)->
    #mysql_curor{rows=Rows} = Curor,
    RowMax = length(Rows),
    if 
	  RowMax=:=0 -> norow;
	  true->
      NextCur = Curor#mysql_curor{currowindex =1},
	  NextCur
   end.

nextrow(Curor)->
    #mysql_curor{rows=Rows,currowindex =CurRowIndex} = Curor,
    RowMax = length(Rows),
    if 
	  RowMax=< CurRowIndex -> eof;
	  true->
      NextCur = Curor#mysql_curor{currowindex =CurRowIndex+1},
	  NextCur
   end.
prerow(Curor)->
    #mysql_curor{rows=Rows,currowindex =CurRowIndex} = Curor,
    RowMax = length(Rows),
    if 
	  RowMax=:= 0 -> norow;
	  true->
        if 
          CurRowIndex=:=1 ->bof;
           true->
            NextCur = Curor#mysql_curor{currowindex =CurRowIndex-1},
	        NextCur
        end
   end.

get_data([],_,_)->
   not_found;
get_data([H|Result],CurIndex,Index)->
   case H of
      {data,Data} ->
         CurIndex1 = CurIndex+1,  
         if 
            CurIndex =:=Index ->Data;
            true->get_data(Result,CurIndex1,Index)
          end;
       {error,_} ->error;
        _->
           get_data(Result,CurIndex,Index)
      end.  

get_fieldIndex(Curor,FieldName)->
    #mysql_curor{fieldinfo = FieldInfos} = Curor,
    LowFieldName = string:to_lower(binary_to_list(FieldName)),
    get_fieldIndex(FieldInfos,LowFieldName,1).

get_fieldIndex([],_,_)
 ->0;
get_fieldIndex([H|FieldInfos],FieldName,Index)->
    {_,FieldName1,_,_} = H,
    LowFieldName = string:to_lower(FieldName1),	
	E = string:equal(FieldName, LowFieldName),
    case    E  of
       true->  Index;
        _->get_fieldIndex(FieldInfos,FieldName,Index+1)
    end.

