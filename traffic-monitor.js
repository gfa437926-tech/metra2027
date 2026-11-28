// js/traffic-monitor.js

// زيادة العداد الحجم (يتم استدعاؤها بعد أي طلب ناجح)
function addTrafficData(sizeInKB) {
    let currentTotal = parseFloat(localStorage.getItem('session_traffic_kb') || 0);
    let newTotal = currentTotal + sizeInKB;
    localStorage.setItem('session_traffic_kb', newTotal.toFixed(2));
    console.log(`📊 [مراقبة] تم إضافة ${sizeInKB.toFixed(2)} KB - الإجمالي: ${newTotal.toFixed(2)} KB`);
}

// بدء جلسة جديدة عند تسجيل الدخول
async function startSession(user) {
    try {
        const { data, error } = await supabaseClient
            .from('user_sessions')
            .insert([{
                user_id: user.id,
                user_name: user.name || user.email,
                station: user.station || 'غير محدد',
                session_status: 'active'
            }])
            .select();

        if (error) throw error;
        localStorage.setItem('active_session_id', data[0].id);
        localStorage.setItem('session_traffic_kb', '0');
        console.log('✅ بدأت جلسة المراقبة بنجاح، ID:', data[0].id);
        return true;
    } catch (err) {
        console.error('❌ فشل بدء جلسة المراقبة:', err);
        return false;
    }
}

// إنهاء الجلسة وحفظ الإحصائيات (تُستدعى عند الخروج أو إغلاق المتصفح)
async function endSessionAndSave() {
    const sessionId = localStorage.getItem('active_session_id');
    const totalKB = localStorage.getItem('session_traffic_kb');
    if (!sessionId) return;

    try {
        const { error } = await supabaseClient
            .from('user_sessions')
            .update({
                logout_time: new Date(),
                total_kb_consumed: parseFloat(totalKB || 0),
                session_status: 'closed'
            })
            .eq('id', sessionId);

        if (error) throw error;
        console.log(`✅ تم إغلاق الجلسة ${sessionId} - الاستهلاك: ${totalKB || 0} KB`);
        localStorage.removeItem('active_session_id');
        localStorage.removeItem('session_traffic_kb');
    } catch (err) {
        console.error('❌ فشل إغلاق الجلسة:', err);
    }
}

// إرفاق المراقب بكائن supabaseClient (إذا كان موجوداً)
// نقوم بتعديل دالة insert/select/update لتحسب الحجم تلقائياً
function attachTrafficInterceptor() {
    if (!window.supabaseClient) return;
    const originalFrom = window.supabaseClient.from;
    window.supabaseClient.from = function(table) {
        const builder = originalFrom.call(this, table);
        const originalInsert = builder.insert;
        const originalSelect = builder.select;
        const originalUpdate = builder.update;

        builder.insert = function(data) {
            const size = new Blob([JSON.stringify(data)]).size / 1024;
            addTrafficData(size);
            return originalInsert.call(this, data);
        };
        builder.select = function(columns) {
            const result = originalSelect.call(this, columns);
            // لا يمكننا حساب حجم النتيجة إلا بعد await، لذلك نضيف وهمي
            return result;
        };
        // يمكنك إضافة باقي الدوال بنفس الطريقة
        return builder;
    };
}

// إعداد الاستماع لإغلاق الصفحة أو علامة التبويب
window.addEventListener('beforeunload', () => {
    endSessionAndSave();
});

// أيضاً عند الخروج من الصفحة يدوياً (مثلاً زر logout)
window.endSessionManually = endSessionAndSave;