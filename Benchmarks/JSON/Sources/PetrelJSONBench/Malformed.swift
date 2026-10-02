import Foundation
import Petrel

func malformed(_ strategies: [Strategy], _ out: String, corpus: [Fixture]) throws {
 struct Case { let name: String; let data: Data; let kind: Int }
 var cases: [Case] = []
 func add(_ name: String, _ text: String, _ kind: Int = 0) { cases.append(Case(name:name,data:Data(text.utf8),kind:kind)) }
 add("valid_unicode", "{\"s\":\"é🦋東京é\"}")
 add("truncated", "{\"s\":\"hello\"")
 add("invalid_escape", #"{"s":"\q"}"#)
 add("malformed_unicode_hex", #"{"s":"\uGGGG"}"#)
 add("lone_high_surrogate", #"{"s":"\uD800"}"#)
 add("lone_low_surrogate", #"{"s":"\uDC00"}"#)
 add("valid_surrogate_pair", #"{"s":"\uD83D\uDE00"}"#)
 add("embedded_nul", #"{"s":"a\u0000b"}"#)
 cases.append(Case(name:"invalid_utf8",data:Data([123,34,115,34,58,34,0xc0,0xaf,34,125]),kind:0))
 add("int64_max", "{\"i\":9223372036854775807}")
 add("int64_min", "{\"i\":-9223372036854775808}")
 add("int64_overflow", "{\"i\":9223372036854775808}")
 add("uint64_max", "{\"u\":18446744073709551615}")
 add("uint64_overflow", "{\"u\":18446744073709551616}")
 add("uint64_negative", "{\"u\":-1}")
 add("integer_as_float", "{\"i\":1.0}")
 add("integer_exponent", "{\"i\":1e2}")
 add("large_integral_decimal", "{\"i\":9007199254740993.0}")
 add("int64_max_decimal", "{\"i\":9223372036854775807.0}")
 add("huge_ignored_numeric", "{\"ignored\":1e400}")
 add("fractional_integer", "{\"i\":1.1}")
 add("negative_zero", "{\"d\":-0.0}")
 add("large_double", "{\"d\":1.7976931348623157e308}")
 add("double_overflow", "{\"d\":1e400}")
 add("small_double", "{\"d\":5e-324}")
 add("nan_token", "{\"d\":NaN}")
 add("infinity_token", "{\"d\":Infinity}")
 add("missing_required", "{}",1)
 add("null_required", "{\"required\":null}",1)
 add("null_optional", "{\"s\":null}")
 add("absent_optional", "{}")
 add("wrong_optional_type", "{\"s\":3}")
 add("duplicate_key", "{\"i\":1,\"i\":2}")
 add("trailing_comma", "{\"i\":1,}")
 add("trailing_garbage", "{\"i\":1} false")
 add("unknown_type", #"{"value":{"$type":"example.unknown.future","text":"keep me","items":[1,null,true,{"x":"y"}]}}"#,2)
 add("known_record_missing_fields", #"{"value":{"$type":"app.bsky.feed.post","text":"missing date"}}"#,2)
 add("known_record_extra_field", #"{"value":{"$type":"app.bsky.feed.post","text":"post","createdAt":"2026-01-01T00:00:00.000Z","future":true}}"#,2)
 add("deep_64", "{\"value\":" + String(repeating:"[",count:64) + "0" + String(repeating:"]",count:64) + "}",2)
 add("deep_600", "{\"value\":" + String(repeating:"[",count:600) + "0" + String(repeating:"]",count:600) + "}",2)
 var rows: [Correctness] = []
 for c in cases {
   for s in strategies where s != .simdDirect {
     do {
       let context = Context(s)
       let value: Model
       switch c.kind {
       case 1: value = try context.decode(RequiredProbe.self,c.data)
       case 2: value = try context.decode(DynamicProbe.self,c.data)
       default: value = try context.decode(Probe.self,c.data)
       }
       do {
         let output = try canonical(value)
         rows.append(.init(fixture:c.name,strategy:s.rawValue,status:"accepted",detail:String(data:output,encoding:.utf8) ?? "<binary>"))
       } catch {
         rows.append(.init(fixture:c.name,strategy:s.rawValue,status:"accepted_encoding_failed",detail:String(describing:error)))
       }
     } catch { rows.append(.init(fixture:c.name,strategy:s.rawValue,status:"rejected",detail:String(describing:error))) }
   }
 }
 // Exercise specialized timeline traversal with full corpus and malformed outer fields.
 if strategies.contains(.simdDirect) {
   for (name,text) in [("timeline_missing_feed","{}"),("timeline_null_feed","{\"feed\":null}"),("timeline_null_cursor","{\"feed\":[],\"cursor\":null}"),("timeline_wrong_cursor","{\"feed\":[],\"cursor\":3}"),("timeline_missing_post","{\"feed\":[{}]}"),("timeline_wrong_optional_reason","{\"feed\":[],\"cursor\":{}}") ] {
     for s in [Strategy.foundationFresh,.simdDirect,.foundationSpecialized] {
       do {
         let data = Data(text.utf8)
         let value = s == .simdDirect ? try directTimeline(data) : s == .foundationSpecialized ? try directFoundationTimeline(data) : try JSONDecoder().decode(AppBskyFeedGetTimeline.Output.self,from:data)
         rows.append(.init(fixture:name,strategy:s.rawValue,status:"accepted",detail:String(data:try canonical(value),encoding:.utf8)!))
       } catch { rows.append(.init(fixture:name,strategy:s.rawValue,status:"rejected",detail:String(describing:error))) }
     }
   }
 }
 if let fixture = corpus.first(where: { $0.entry.id == "large-feed" }),
    let object = try JSONSerialization.jsonObject(with:fixture.data) as? [String:Any],
    let first = (object["feed"] as? [[String:Any]])?.first {
   let base: [String:Any] = ["$type":"app.bsky.feed.post","text":"hello","createdAt":"2026-01-01T00:00:00.000Z"]
   let changes: [(String,String,Any)] = [
     ("optional_langs_wrong_type","langs",3),("optional_langs_invalid_item","langs",[3]),
     ("optional_tags_wrong_type","tags",true),("optional_tags_null","tags",NSNull()),
     ("optional_facets_wrong_type","facets",[true]),("unknown_record_field","future",["x":42]),
     ("record_date_invalid","createdAt","bad"),("record_date_long_precision","createdAt","2026-01-01T00:00:00.123456789Z"),
     ("record_text_wrong_type","text",23),("record_type_unknown","$type","example.future.post"),
     ("facet_link_trim","facets",[["index":["byteStart":0,"byteEnd":5],"features":[["$type":"app.bsky.richtext.facet#link","uri":" https://example.com "]]]]),
     ("facet_unknown_feature","facets",[["index":["byteStart":0,"byteEnd":5],"features":[["$type":"example.future.facet","value":true]]]])
   ]
   for (name,key,changed) in changes {
     var record = base; record[key] = changed
     var entry = first; var post = entry["post"] as! [String:Any]; post["record"] = record; entry["post"] = post
     let bytes = try JSONSerialization.data(withJSONObject:["feed":[entry]],options:[.sortedKeys])
     for s in strategies {
       do {
         let result: AppBskyFeedGetTimeline.Output
         if s == .simdDirect { result = try directTimeline(bytes) }
         else if s == .foundationSpecialized { result = try directFoundationTimeline(bytes) }
         else { result = try Context(s).decode(AppBskyFeedGetTimeline.Output.self,bytes) }
         let value = try canonical(result)
         rows.append(.init(fixture:name,strategy:s.rawValue,status:"accepted",detail:String(data:value,encoding:.utf8)!))
       } catch { rows.append(.init(fixture:name,strategy:s.rawValue,status:"rejected",detail:String(describing:error))) }
     }
   }
 }
 try save(rows,out+"/malformed.json")
}
