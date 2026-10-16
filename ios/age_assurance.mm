#import <Foundation/Foundation.h>
#import "SyntaxCircusAgeAssurance-Swift.h"
#include "core/object/ref_counted.h"
#include "core/object/class_db.h"
#include "core/config/engine.h"
#include <mutex>
#include <string>

static std::mutex mailbox;
static int active_request = 0;
static std::string answer;
class SyntaxCircusAgeAssurance : public RefCounted {
    GDCLASS(SyntaxCircusAgeAssurance, RefCounted);
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("request_check", "request", "minimum", "allow_prompt"), &SyntaxCircusAgeAssurance::request_check);
        ClassDB::bind_method(D_METHOD("take_result", "request"), &SyntaxCircusAgeAssurance::take_result);
        ClassDB::bind_method(D_METHOD("cancel_check", "request"), &SyntaxCircusAgeAssurance::cancel_check);
    }
public:
    void request_check(int request, int minimum, bool allow_prompt) {
        { std::lock_guard<std::mutex> lock(mailbox); active_request = request; answer.clear(); }
        [SCAgeAssurance request:minimum allowPrompt:allow_prompt completion:^(NSString *result) {
            std::lock_guard<std::mutex> lock(mailbox);
            if (active_request == request) answer = result.UTF8String;
        }];
    }
    String take_result(int request) {
        std::lock_guard<std::mutex> lock(mailbox);
        if (active_request != request) return String();
        String result = String::utf8(answer.c_str()); answer.clear(); return result;
    }
    void cancel_check(int request) {
        std::lock_guard<std::mutex> lock(mailbox);
        if (active_request == request) { active_request = 0; answer.clear(); }
    }
};
static Ref<SyntaxCircusAgeAssurance> bridge;
void sc_age_init() {
    ClassDB::register_class<SyntaxCircusAgeAssurance>();
    bridge = memnew(SyntaxCircusAgeAssurance);
    Engine::get_singleton()->add_singleton(Engine::Singleton("SyntaxCircusAgeAssurance",bridge.ptr()));
}
void sc_age_deinit() {
    { std::lock_guard<std::mutex> lock(mailbox); active_request = 0; answer.clear(); }
    if (bridge.is_valid()) { Engine::get_singleton()->remove_singleton("SyntaxCircusAgeAssurance"); bridge.unref(); }
}
