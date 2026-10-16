package com.reloop.app;
import java.util.*;
import java.nio.file.*;
import java.security.SecureRandom;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class DemoData implements ApplicationRunner {
 private final JdbcTemplate j;private final PasswordEncoder encoder;
 public DemoData(JdbcTemplate j,PasswordEncoder e){this.j=j;encoder=e;}
 @Override @Transactional public void run(ApplicationArguments a)throws Exception{
  if(j.queryForObject("SELECT COUNT(*) FROM RC_USERS",Integer.class)>0)return;
  var centres=j.queryForList("SELECT ID FROM RC_CENTRES ORDER BY ID",Long.class);
  if(centres.isEmpty())throw new IllegalStateException("Run database schema and reference seed first.");
  byte[] bytes=new byte[9];new SecureRandom().nextBytes(bytes);String pass="Loop!"+Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
  Files.createDirectories(Path.of(".local"));
  Files.writeString(Path.of(".local/demo-logins.txt"),"ReLoop local demonstration accounts\nPassword for all seeded accounts: "+pass+"\nAdmin: admin@reloop.test\nStaff (first centre): staff@reloop.test\nOther staff: staff2@reloop.test, staff3@reloop.test\nCitizen: citizen@reloop.test\nOther citizens: citizen2@reloop.test through citizen8@reloop.test\nDo not publish this file.\n");
  String hash=encoder.encode(pass);
  add("ReLoop Administrator","admin@reloop.test",hash,"ADMIN",null);
  for(int i=0;i<centres.size();i++)add("Centre Operator "+(i+1),"staff"+(i==0?"":i+1)+"@reloop.test",hash,"STAFF",centres.get(i));
  String[] names={"Ananya Rao","Arjun Kumar","Meera Shah","Dev Patel","Sara Thomas","Vikram Sen","Nila Das","Rohan Nair"};
  for(int i=0;i<names.length;i++)add(names[i],"citizen"+(i==0?"":i+1)+"@reloop.test",hash,"CITIZEN",null);
  var citizens=j.queryForList("SELECT ID FROM RC_USERS WHERE ROLE='CITIZEN' ORDER BY ID",Long.class);
  var materials=j.queryForList("SELECT ID FROM RC_MATERIALS ORDER BY ID",Long.class);
  long actor=j.queryForObject("SELECT ID FROM RC_USERS WHERE EMAIL='admin@reloop.test'",Long.class);
  for(int i=0;i<18;i++){
   long citizen=citizens.get(i%7),centre=centres.get(i%Math.min(2,centres.size()));
   String status=i<9?"SCHEDULED":i<13?"REQUESTED":i<16?"SCHEDULED":"CANCELLED";
   j.update("INSERT INTO RC_PICKUPS(CITIZEN_ID,CENTRE_ID,PICKUP_ADDRESS,PREFERRED_DATE,SCHEDULED_DATE,STATUS,NOTES) VALUES(?,?,?,TRUNC(SYSDATE)+?,CASE WHEN ?='SCHEDULED' THEN TRUNC(SYSDATE)+? ELSE NULL END,?,?)",citizen,centre,(10+i)+" Green Street, Chennai",i<9?-(i%5):i%4,status,i<9?-(i%5):i%4,status,"Synthetic demonstration pickup "+(i+1));
   long pickup=j.queryForObject("SELECT MAX(ID) FROM RC_PICKUPS",Long.class);
   for(int k=0;k<2;k++){
    long mat=materials.get((i+k)%Math.min(5,materials.size()));double kg=3+i%6+k;
    j.update("INSERT INTO RC_PICKUP_ITEMS(PICKUP_ID,MATERIAL_ID,ESTIMATED_KG,COLLECTED_KG,ACCEPTED_KG) VALUES(?,?,?,?,?)",pickup,mat,kg,i<9?kg:null,i<9?kg-0.5:null);
   }
   if(i<9){
    j.update("BEGIN PR_CONFIRM_COLLECTION(?,?); END;",pickup,actor);
    if(i<6)j.execute((java.sql.Connection c)->{try(var st=c.prepareCall("{call PR_POST_REWARDS(?,?,?)}")){st.setLong(1,pickup);st.setLong(2,actor);st.registerOutParameter(3,java.sql.Types.NUMERIC);st.execute();return null;}});
   }
  }
 }
 private void add(String name,String email,String hash,String role,Long centre){j.update("INSERT INTO RC_USERS(FULL_NAME,EMAIL,PASSWORD_HASH,ROLE,CENTRE_ID,ACTIVE) VALUES(?,?,?,?,?,1)",name,email,hash,role,centre);}
}
