package com.reloop.app;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.nio.file.*;
import java.util.*;
import javax.sql.DataSource;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.*;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.PlatformTransactionManager;

@SpringBootApplication
public class Application {
 public static void main(String[] args) { SpringApplication.run(Application.class,args); }
 @Bean("dbSettings") Map<String,String> dbSettings() throws Exception {
  Path p=Path.of(".local/db-secrets.json");
  Map<String,String> m=Files.exists(p)?new ObjectMapper().readValue(Files.readString(p),new TypeReference<Map<String,String>>(){}):new HashMap<>();
  Map.of("url","RC_DB_URL","appUsername","RC_DB_USER","appPassword","RC_DB_PASSWORD","labUsername","RC_LAB_USER","labPassword","RC_LAB_PASSWORD").forEach((key,env)->{String v=System.getenv(env);if(v!=null)m.put(key,v);});
  if(!m.containsKey("url"))throw new IllegalStateException("Database configuration missing: run database setup and configure .local/db-secrets.json or RC_DB_* variables.");
  return m;
 }
 private HikariDataSource pool(Map<String,String> m,String prefix,boolean app){
  HikariConfig c=new HikariConfig();c.setJdbcUrl(m.get("url"));c.setUsername(m.get(prefix+"Username"));c.setPassword(m.get(prefix+"Password"));
  c.setMaximumPoolSize(app?6:2);c.setMinimumIdle(1);c.setConnectionTimeout(10000);c.setPoolName(app?"ReLoop-app":"ReLoop-lab");
  if(app)c.setConnectionInitSql("ALTER SESSION SET CURRENT_SCHEMA=RC_OWNER");
  return new HikariDataSource(c);
 }
 @Bean @Primary DataSource dataSource(@Qualifier("dbSettings") Map<String,String> m){return pool(m,"app",true);}
 @Bean("labDataSource") DataSource labDataSource(@Qualifier("dbSettings") Map<String,String> m){return pool(m,"lab",false);}
 @Bean @Primary JdbcTemplate jdbcTemplate(@Qualifier("dataSource") DataSource d){return new JdbcTemplate(d);}
 @Bean("labJdbc") JdbcTemplate labJdbc(@Qualifier("labDataSource") DataSource d){JdbcTemplate j=new JdbcTemplate(d);j.setQueryTimeout(15);return j;}
 @Bean PlatformTransactionManager transactionManager(@Qualifier("dataSource") DataSource d){return new DataSourceTransactionManager(d);}
}
