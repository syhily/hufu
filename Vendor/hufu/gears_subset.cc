// Hufu's librime gears subset.
//
// librime's static build calls rime_require_module_gears(), which would pull in
// gears_module.o and every gear component. Defining the same C++ symbol here
// keeps that object out of the link; the consumer then registers only the
// components it actually needs through the public Registry API.

#include <rime/component.h>
#include <rime/registry.h>
#include <rime/gear/abc_segmentor.h>
#include <rime/gear/affix_segmentor.h>
#include <rime/gear/ascii_composer.h>
#include <rime/gear/ascii_segmentor.h>
#include <rime/gear/echo_translator.h>
#include <rime/gear/editor.h>
#include <rime/gear/fallback_segmentor.h>
#include <rime/gear/history_translator.h>
#include <rime/gear/key_binder.h>
#include <rime/gear/matcher.h>
#include <rime/gear/navigator.h>
#include <rime/gear/punctuator.h>
#include <rime/gear/recognizer.h>
#include <rime/gear/reverse_lookup_translator.h>
#include <rime/gear/schema_list_translator.h>
#include <rime/gear/script_translator.h>
#include <rime/gear/selector.h>
#include <rime/gear/shape.h>
#include <rime/gear/simplifier.h>
#include <rime/gear/speller.h>
#include <rime/gear/switch_translator.h>
#include <rime/gear/table_translator.h>
#include <rime/gear/uniquifier.h>

// Same signature and C++ linkage as librime's rime_api.cc declaration.
void rime_require_module_gears() {}

extern "C" void hufu_rime_register_components(void) {
  using namespace rime;
  Registry& r = Registry::instance();

  // processors
  r.Register("ascii_composer", new Component<AsciiComposer>);
  r.Register("recognizer", new Component<Recognizer>);
  r.Register("key_binder", new Component<KeyBinder>);
  r.Register("speller", new Component<Speller>);
  r.Register("punctuator", new Component<Punctuator>);
  r.Register("selector", new Component<Selector>);
  r.Register("navigator", new Component<Navigator>);
  r.Register("express_editor", new Component<ExpressEditor>);
  r.Register("shape_processor", new Component<ShapeProcessor>);

  // segmentors
  r.Register("ascii_segmentor", new Component<AsciiSegmentor>);
  r.Register("matcher", new Component<Matcher>);
  r.Register("affix_segmentor", new Component<AffixSegmentor>);
  r.Register("abc_segmentor", new Component<AbcSegmentor>);
  r.Register("punct_segmentor", new Component<PunctSegmentor>);
  r.Register("fallback_segmentor", new Component<FallbackSegmentor>);

  // translators
  r.Register("punct_translator", new Component<PunctTranslator>);
  r.Register("table_translator", new Component<TableTranslator>);
  r.Register("reverse_lookup_translator",
             new Component<ReverseLookupTranslator>);
  r.Register("history_translator", new Component<HistoryTranslator>);
  r.Register("echo_translator", new Component<EchoTranslator>);
  r.Register("script_translator", new Component<ScriptTranslator>);
  r.Register("schema_list_translator", new Component<SchemaListTranslator>);
  r.Register("switch_translator", new Component<SwitchTranslator>);

  // filters
  r.Register("simplifier", new SimplifierComponent);
  r.Register("uniquifier", new Component<Uniquifier>);

  // formatters
  r.Register("shape_formatter", new Component<ShapeFormatter>);
}

extern "C" int hufu_rime_check_components(void) {
  using namespace rime;
  static const char* const names[] = {
      "ascii_composer",   "recognizer",      "key_binder",
      "speller",          "punctuator",      "selector",
      "navigator",        "express_editor",  "shape_processor",
      "ascii_segmentor",  "matcher",         "affix_segmentor",
      "abc_segmentor",    "punct_segmentor", "fallback_segmentor",
      "punct_translator", "table_translator", "reverse_lookup_translator",
      "history_translator", "echo_translator", "script_translator",
      "schema_list_translator", "switch_translator",
      "simplifier",       "uniquifier",      "shape_formatter",
  };
  int missing = 0;
  for (const char* name : names) {
    if (!Registry::instance().Find(name))
      ++missing;
  }
  return missing;
}
