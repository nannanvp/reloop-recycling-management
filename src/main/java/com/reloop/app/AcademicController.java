package com.reloop.app;

import java.sql.*;
import java.util.*;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Fixed demonstrations only: never accepts arbitrary SQL or object identifiers. */
@RestController @RequestMapping("/api/academic")
public class AcademicController {
 private final JdbcTemplate db,lab;private final DataSource labSource;
 public AcademicController(JdbcTemplate d,@Qualifier("labJdbc") JdbcTemplate l,@Qualifier("labDataSource")DataSource s){db=d;lab=l;labSource=s;}
 private void requireAdmin(){String email=org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getName();if(db.queryForObject("SELECT COUNT(*) FROM RC_USERS WHERE EMAIL=? AND ROLE='ADMIN' AND ACTIVE=1",Integer.class,email)!=1)throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Active administrator access required");}
 private Map<String,String> topic(String id,String title,String description,String sql){return Map.of("id",id,"title",title,"description",description,"sql",sql);}
 private List<Map<String,String>> catalogue(){return List.of(
  topic("1","DDL, DML and DQL","Operational forms INSERT, UPDATE and DELETE. Use the isolated sandbox below for live DDL.","SELECT table_name FROM all_tables WHERE owner='RC_OWNER' ORDER BY table_name"),
  topic("2","Operators, functions and clauses","Filter pending work with comparisons, logical operators, LIKE and ordering.","SELECT id,pickup_address,status,preferred_date FROM RC_PICKUPS WHERE status IN ('REQUESTED','SCHEDULED') AND UPPER(pickup_address) LIKE '%STREET%' AND preferred_date BETWEEN TRUNC(SYSDATE)-30 AND TRUNC(SYSDATE)+30 ORDER BY preferred_date"),
  topic("3","E-R diagram and normalization","The diagram maps the actual eight-table schema. Separate pickup headers, material lines, centres and immutable rewards support 3NF.","SELECT table_name,column_name,data_type,nullable FROM all_tab_columns WHERE owner='RC_OWNER' ORDER BY table_name,column_id"),
  topic("4","Single-row and group functions","Summarize accepted weight on normalized tables; evaluate formatting, null handling and aggregates.","SELECT UPPER(TRIM(m.name)) material,LOWER(m.name) lowercase_name,SUBSTR(m.name,1,3) abbreviation,LENGTH(m.name) name_length,COUNT(i.id) line_count,ROUND(NVL(AVG(i.accepted_kg),0),3) average_kg,NVL(SUM(i.accepted_kg),0) total_kg,MIN(i.accepted_kg) minimum_kg,MAX(i.accepted_kg) maximum_kg FROM RC_MATERIALS m LEFT JOIN RC_PICKUP_ITEMS i ON i.material_id=m.id GROUP BY m.name HAVING COUNT(i.id)>=0 ORDER BY total_kg DESC"),
  topic("5","Retrieve data using subqueries","A correlated NOT EXISTS finds materials with no collected pickups.","SELECT m.id,m.name FROM RC_MATERIALS m WHERE NOT EXISTS(SELECT 1 FROM RC_PICKUP_ITEMS i JOIN RC_PICKUPS p ON p.id=i.pickup_id WHERE i.material_id=m.id AND p.status='COLLECTED')"),
  topic("6","Retrieve data using JOINs","A LEFT JOIN retains centres with no pickups; linked queries also join citizens and material records.","SELECT c.name centre,p.id pickup_id,u.full_name citizen,p.status FROM RC_CENTRES c LEFT JOIN RC_PICKUPS p ON p.centre_id=c.id LEFT JOIN RC_USERS u ON u.id=p.citizen_id ORDER BY c.id,p.id"),
  topic("7","Retrieve data using VIEWs","This is a live SELECT from an Oracle stored view, also used by operational reports.","SELECT * FROM VW_CENTRE_MATERIAL_TOTALS"),
  topic("8","PL/SQL control structures, functions and procedures","FN_REWARD_POINTS calculates 8 kg × 10 = 80. The run also executes conditional statements and three loop forms.","SELECT FN_REWARD_POINTS(8,10) reward_points FROM DUAL"),
  topic("9","PL/SQL CURSORs","Explicit OPEN/FETCH/CLOSE retrieves material rows. Production processing uses FOR UPDATE and WHERE CURRENT OF; the report procedure exposes SYS_REFCURSOR.","DECLARE CURSOR c IS SELECT name FROM RC_MATERIALS ORDER BY id; v_name RC_MATERIALS.name%TYPE; v_text VARCHAR2(4000):=''; BEGIN OPEN c; LOOP FETCH c INTO v_name; EXIT WHEN c%NOTFOUND; v_text:=v_text||v_name||'; '; END LOOP; CLOSE c; ?:=v_text; END;"),
  topic("10","JDBC database connectivity","Live JDBC metadata verifies the Java application is connected to Oracle. SQLPlus remains the script and terminal client.","Connection → PreparedStatement / CallableStatement → Oracle Database → ResultSet")
 );}
 @GetMapping("/topics") Object topics(){requireAdmin();return Map.of("items",catalogue());}
 @PostMapping("/run/{id}") Object run(@PathVariable String id){
  requireAdmin();
  var t=catalogue().stream().filter(x->x.get("id").equals(id)).findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Unknown demonstration"));
  String sql=t.get("sql");Object rows;
  if(id.equals("9")){rows=List.of(Map.of("cursorOutput",db.execute((ConnectionCallback<String>)c->{try(var s=c.prepareCall(sql)){s.registerOutParameter(1,Types.VARCHAR);s.execute();return s.getString(1);}})));}
  else if(id.equals("10")){rows=List.of(db.execute((ConnectionCallback<Map<String,Object>>)c->{var m=c.getMetaData();return Map.of("database",m.getDatabaseProductName(),"databaseVersion",m.getDatabaseMajorVersion(),"driver",m.getDriverName(),"driverVersion",m.getDriverVersion(),"queryLanguage","Oracle SQL / PL/SQL","client","JDBC Thin");}));}
  else {rows=db.query(sql,(r,n)->OperationsController.row(r));if(id.equals("8")){
   String result=db.execute((ConnectionCallback<String>)c->{try(var s=c.prepareCall("DECLARE n NUMBER:=0; k NUMBER:=0; label VARCHAR2(30); BEGIN FOR i IN 1..3 LOOP n:=n+i; END LOOP; WHILE k<2 LOOP k:=k+1; END LOOP; LOOP n:=n+1; EXIT WHEN n>=8; END LOOP; IF n=8 THEN label:='IF passed'; ELSIF n>8 THEN label:='higher'; ELSE label:='lower'; END IF; ?:=label||', CASE='||CASE WHEN k=2 THEN 'passed' ELSE 'failed' END||', loops total='||n; END;")){s.registerOutParameter(1,Types.VARCHAR);s.execute();return s.getString(1);}});
   return Map.of("items",rows,"sql",sql,"message",result);
  }}return Map.of("items",rows,"sql",sql,"message","Executed against Oracle successfully");
 }
 @GetMapping(value="/script/{id}",produces="text/plain") String script(@PathVariable String id){requireAdmin();var t=catalogue().stream().filter(x->x.get("id").equals(id)).findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));String sql=t.get("sql");if(id.equals("9"))return "SET SERVEROUTPUT ON\nVARIABLE result VARCHAR2(4000)\n"+sql.replace("?",":result")+"\n/\nPRINT result\n";if(id.equals("10"))return "-- JDBC source: OperationsController.java and AcademicController.java\nSELECT SYS_CONTEXT('USERENV','CURRENT_SCHEMA') current_schema FROM DUAL;\n";return "SET PAGESIZE 100\nSET LINESIZE 220\n"+sql+";\n";}
 private String table(){return lab.queryForObject("SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME='RC_PRACTICE'",Integer.class)>0?"RC_PRACTICE":"RC_PRACTICE_RENAMED";}
 @PostMapping("/sandbox/{action}") synchronized Object sandbox(@PathVariable String action)throws Exception{
  requireAdmin();
  String sql;String message="Executed in isolated RC_LAB schema.";String t=table();
  switch(action){
   case "create":sql="CREATE TABLE RC_PRACTICE(ID NUMBER PRIMARY KEY, MATERIAL VARCHAR2(40), KG NUMBER(10,3) CHECK(KG>=0))";break;
   case "insert":sql="INSERT INTO "+t+"(ID,MATERIAL,KG) SELECT NVL(MAX(ID),0)+1,'Paper',5 FROM "+t;break;
   case "add-column":sql="ALTER TABLE "+t+" ADD (NOTE VARCHAR2(40))";break;
   case "modify-column":sql="ALTER TABLE "+t+" MODIFY (NOTE VARCHAR2(100))";break;
   case "rename-column":sql="ALTER TABLE "+t+" RENAME COLUMN NOTE TO REMARK";break;
   case "drop-column":sql="ALTER TABLE "+t+" DROP COLUMN REMARK";break;
   case "comment":sql="COMMENT ON TABLE "+t+" IS 'Disposable recycling academic sandbox'";break;
   case "rename":sql="RENAME RC_PRACTICE TO RC_PRACTICE_RENAMED";break;
   case "truncate":sql="TRUNCATE TABLE "+t;message="Table truncated. Oracle DDL implicitly commits; these rows cannot be rolled back.";break;
   case "drop":sql="DROP TABLE "+t+" PURGE";break;
   case "merge":sql="MERGE INTO "+t+" d USING (SELECT 100 id,'Plastic' material,7 kg FROM DUAL) s ON(d.id=s.id) WHEN MATCHED THEN UPDATE SET d.kg=s.kg WHEN NOT MATCHED THEN INSERT(id,material,kg) VALUES(s.id,s.material,s.kg)";break;
   case "view-check":{
    sql="CREATE OR REPLACE VIEW RC_POSITIVE AS SELECT ID,MATERIAL,KG FROM "+t+" WHERE KG>=2 WITH CHECK OPTION";lab.execute(sql);
    try{lab.update("INSERT INTO RC_POSITIVE VALUES(999,'Rejected demonstration',1)");throw new IllegalStateException("Check option failed");}catch(org.springframework.dao.DataAccessException e){if(!Objects.toString(e.getMostSpecificCause().getMessage(),"").contains("ORA-01402"))throw e;}
    return Map.of("sql",sql,"items",lab.queryForList("SELECT * FROM RC_POSITIVE"),"message","WITH CHECK OPTION correctly rejected KG=1 (ORA-01402).");
   }
   case "view-readonly":{
    sql="CREATE OR REPLACE VIEW RC_READONLY AS SELECT ID,MATERIAL,KG FROM "+t+" WITH READ ONLY";lab.execute(sql);
    try{lab.update("INSERT INTO RC_READONLY VALUES(998,'Rejected',3)");throw new IllegalStateException("Read-only check failed");}catch(org.springframework.dao.DataAccessException e){if(!Objects.toString(e.getMostSpecificCause().getMessage(),"").contains("ORA-42399"))throw e;}
    return Map.of("sql",sql,"items",lab.queryForList("SELECT * FROM RC_READONLY"),"message","WITH READ ONLY correctly rejected an INSERT (ORA-42399).");
   }
   case "tcl":return tcl(t);
   case "reset":{
    for(String name:List.of("RC_POSITIVE","RC_READONLY")){if(lab.queryForObject("SELECT COUNT(*) FROM USER_VIEWS WHERE VIEW_NAME=?",Integer.class,name)>0)lab.execute("DROP VIEW "+name);}
    for(String name:List.of("RC_PRACTICE","RC_PRACTICE_RENAMED")){if(lab.queryForObject("SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME=?",Integer.class,name)>0)lab.execute("DROP TABLE "+name+" PURGE");}
    return Map.of("sql","DROP known RC_LAB practice objects only","items",List.of(),"message","Sandbox reset. Operational data was not accessed.");
   }
   default:throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Unknown sandbox action");
  }
  lab.execute(sql);String now=table();List<Map<String,Object>> rows=List.of();
  if(lab.queryForObject("SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME=?",Integer.class,now)>0)rows=lab.queryForList("SELECT * FROM "+now+" FETCH FIRST 30 ROWS ONLY");
  return Map.of("sql",sql,"items",rows,"columns",lab.queryForList("SELECT COLUMN_NAME,DATA_TYPE,DATA_LENGTH FROM USER_TAB_COLUMNS WHERE TABLE_NAME=? ORDER BY COLUMN_ID",now),"message",message);
 }
 private Object tcl(String t)throws Exception{
  try(Connection c=labSource.getConnection()){
   boolean auto=c.getAutoCommit();c.setAutoCommit(false);
   try(Statement s=c.createStatement()){
    s.executeUpdate("DELETE FROM "+t+" WHERE ID=900");s.executeUpdate("INSERT INTO "+t+" (ID,MATERIAL,KG) VALUES(900,'TCL demo',4)");
    Savepoint sp=c.setSavepoint("BEFORE_CHANGE");s.executeUpdate("UPDATE "+t+" SET KG=9 WHERE ID=900");c.rollback(sp);
    List<Map<String,Object>> result=new ArrayList<>();try(ResultSet r=s.executeQuery("SELECT KG FROM "+t+" WHERE ID=900")){r.next();result.add(Map.of("step","ROLLBACK TO savepoint","kg",r.getBigDecimal(1)));}
    c.rollback();result.add(Map.of("step","ROLLBACK entire transaction","message","temporary insert undone"));
    s.executeUpdate("MERGE INTO "+t+" d USING(SELECT 901 ID FROM DUAL) x ON(d.ID=x.ID) WHEN MATCHED THEN UPDATE SET d.KG=6 WHEN NOT MATCHED THEN INSERT(ID,MATERIAL,KG) VALUES(901,'Committed TCL',6)");c.commit();result.add(Map.of("step","COMMIT","kg",6));
    return Map.of("items",result,"sql","INSERT; SAVEPOINT before_change; UPDATE; ROLLBACK TO before_change; ROLLBACK; MERGE; COMMIT;","message","All steps executed on one dedicated connection.");
   }catch(Exception e){c.rollback();throw e;}finally{c.setAutoCommit(auto);}
  }
 }
}
