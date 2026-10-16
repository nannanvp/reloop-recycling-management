package com.reloop.app;
import java.util.*;
import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {
 @Bean PasswordEncoder passwordEncoder(){return new BCryptPasswordEncoder();}
 @Bean UserDetailsService users(JdbcTemplate jdbc){return email->{
  var rows=jdbc.queryForList("SELECT EMAIL,PASSWORD_HASH,ROLE,ACTIVE FROM RC_USERS WHERE EMAIL=?",email.trim().toLowerCase(Locale.ROOT));
  if(rows.isEmpty())throw new UsernameNotFoundException("Invalid credentials");var r=rows.get(0);
  return User.withUsername(r.get("EMAIL").toString()).password(r.get("PASSWORD_HASH").toString()).roles(r.get("ROLE").toString()).disabled(((Number)r.get("ACTIVE")).intValue()!=1).build();
 };}
 @Bean SecurityFilterChain filter(HttpSecurity h)throws Exception{
  h.authorizeHttpRequests(a->a.requestMatchers("/","/index.html","/*.css","/*.js","/*.svg","/favicon.ico","/api/auth/csrf","/api/auth/register","/api/auth/login").permitAll().requestMatchers("/api/academic/**").hasRole("ADMIN").requestMatchers("/api/**").authenticated().anyRequest().permitAll());
  h.formLogin(f->f.loginProcessingUrl("/api/auth/login").successHandler((req,res,auth)->{res.setContentType("application/json");res.getWriter().write("{\"ok\":true}");}).failureHandler((req,res,e)->{res.setStatus(401);res.setContentType("application/json");res.getWriter().write("{\"message\":\"Invalid email or password\"}");}));
  h.logout(l->l.logoutUrl("/api/auth/logout").logoutSuccessHandler((req,res,auth)->{res.setContentType("application/json");res.getWriter().write("{\"ok\":true}");}));
  h.exceptionHandling(e->e.authenticationEntryPoint((req,res,ex)->{res.setStatus(401);res.setContentType("application/json");res.getWriter().write("{\"message\":\"Please sign in\"}");}).accessDeniedHandler((req,res,ex)->{res.setStatus(403);res.setContentType("application/json");res.getWriter().write("{\"message\":\"This action is not permitted. Refresh and sign in again if your session expired.\"}");}));
  return h.build();
 }
}
