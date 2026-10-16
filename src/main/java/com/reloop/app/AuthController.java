package com.reloop.app;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController @RequestMapping("/api/auth")
public class AuthController {
 private final JdbcTemplate jdbc;private final PasswordEncoder encoder;
 public AuthController(JdbcTemplate j,PasswordEncoder e){jdbc=j;encoder=e;}
 @GetMapping("/csrf") Object csrf(CsrfToken t){return Map.of("token",t.getToken(),"headerName",t.getHeaderName());}
 @GetMapping("/me") Object me(Authentication a){
  var r=jdbc.queryForMap("SELECT ID,FULL_NAME,EMAIL,ROLE,CENTRE_ID,ACTIVE FROM RC_USERS WHERE EMAIL=?",a.getName());
  if(((Number)r.get("ACTIVE")).intValue()!=1)throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Account is inactive");
  Map<String,Object> m=new LinkedHashMap<>();m.put("id",r.get("ID"));m.put("fullName",r.get("FULL_NAME"));m.put("email",r.get("EMAIL"));m.put("role",r.get("ROLE"));m.put("centreId",r.get("CENTRE_ID"));return m;
 }
 @PostMapping("/register") Object register(@RequestBody Map<String,Object> b){
  String name=Objects.toString(b.get("fullName"),"").trim(), email=Objects.toString(b.get("email"),"").trim().toLowerCase(Locale.ROOT),pass=Objects.toString(b.get("password"),"");
  if(name.isBlank()||name.length()>100||!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")||email.length()>150||pass.length()<8||pass.getBytes(java.nio.charset.StandardCharsets.UTF_8).length>72)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enter a name, valid email, and password of at least 8 characters (maximum 72 UTF-8 bytes)");
  jdbc.update("INSERT INTO RC_USERS(FULL_NAME,EMAIL,PASSWORD_HASH,ROLE,ACTIVE) VALUES(?,?,?,'CITIZEN',1)",name,email,encoder.encode(pass));
  return Map.of("ok",true,"message","Account created. You can now sign in.");
 }
}
