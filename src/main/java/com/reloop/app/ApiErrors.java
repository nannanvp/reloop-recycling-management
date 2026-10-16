package com.reloop.app;
import java.util.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import org.springframework.dao.*;
import org.springframework.web.server.ResponseStatusException;
@RestControllerAdvice
public class ApiErrors {
 @ExceptionHandler(ResponseStatusException.class) ResponseEntity<?> status(ResponseStatusException e){return ResponseEntity.status(e.getStatusCode()).body(Map.of("message",Objects.toString(e.getReason(),"Request failed")));}
 @ExceptionHandler(DataIntegrityViolationException.class) ResponseEntity<?> integrity(Exception e){return ResponseEntity.status(409).body(Map.of("message","This record already exists, has dependent records, or violates a data rule."));}
 @ExceptionHandler(DataAccessException.class) ResponseEntity<?> data(DataAccessException e){
  String s=Objects.toString(e.getMostSpecificCause().getMessage(),"");var m=java.util.regex.Pattern.compile("ORA-20[0-9]{3}: ([^\\r\\n]+)").matcher(s);
  if(m.find())return ResponseEntity.status(409).body(Map.of("message",m.group(1)));
  return ResponseEntity.status(503).body(Map.of("message","The database could not complete this request. Check Oracle and try again."));
 }
 @ExceptionHandler({IllegalArgumentException.class,org.springframework.http.converter.HttpMessageNotReadableException.class}) ResponseEntity<?> invalid(Exception e){return ResponseEntity.badRequest().body(Map.of("message","Invalid input. Check required fields and numeric values."));}
}
