import java.nio.file.*;
import java.util.*;
import org.yaml.snakeyaml.*;
import org.yaml.snakeyaml.constructor.SafeConstructor;

// Converts the existing canonical Payment YAML for the offline documentation viewer.
class YamlToJson {
  static String json(Object value) {
    if(value==null)return "null";
    if(value instanceof Number||value instanceof Boolean)return value.toString();
    if(value instanceof Map<?,?> map){var parts=new ArrayList<String>();for(var e:map.entrySet())parts.add(json(e.getKey().toString())+":"+json(e.getValue()));return "{"+String.join(",",parts)+"}";}
    if(value instanceof List<?> list){var parts=new ArrayList<String>();for(var e:list)parts.add(json(e));return "["+String.join(",",parts)+"]";}
    var b=new StringBuilder("\"");for(char c:value.toString().toCharArray()){switch(c){case '"'->b.append("\\\"");case '\\'->b.append("\\\\");case '\n'->b.append("\\n");case '\r'->b.append("\\r");case '\t'->b.append("\\t");default->{if(c<32)b.append(String.format("\\u%04x",(int)c));else b.append(c);}}}return b.append('"').toString();
  }
  public static void main(String[] args)throws Exception{var options=new LoaderOptions();options.setAllowDuplicateKeys(false);Object root=new Yaml(new SafeConstructor(options)).load(Files.readString(Path.of(args[0])));System.out.print(json(root));}
}
