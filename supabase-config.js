// supabase-config.js - ملف محسن لتهيئة Supabase
console.log('🔧 تحميل إعدادات Supabase المحسنة...');

const SUPABASE_CONFIG = {
    url: 'https://vktcvkwqszehgmhqjrkb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrdGN2a3dxc3plaGdtaHFqcmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxNzE3NTEsImV4cCI6MjA3Nzc0Nzc1MX0.KTX1c8BAJpy1Jp3-IDXFRqb4Jo7SLabiwICBtn_mR5o',
    options: {
        auth: {
            autoRefreshToken: true,
            persistSession: true,
            detectSessionInUrl: false,
            storage: localStorage,
            storageKey: 'supabase.auth.token'
        },
        realtime: {
            params: {
                eventsPerSecond: 10
            }
        },
        global: {
            headers: {
                'X-Client-Info': 'soil-temp-app/1.0.0'
            }
        }
    }
};

// تعيين متغيرات عالمية
window.SUPABASE_CONFIG = SUPABASE_CONFIG;
window.SUPABASE_URL = SUPABASE_CONFIG.url;
window.SUPABASE_ANON_KEY = SUPABASE_CONFIG.anonKey;

// دالة لتهيئة Supabase بشكل آمن
function initializeSupabase() {
    try {
        // التحقق من وجود مكتبة Supabase
        if (typeof supabase === 'undefined' || !supabase.createClient) {
            console.error('❌ مكتبة Supabase غير محملة');
            return null;
        }
        
        // التحقق من بيانات التهيئة
        if (!SUPABASE_CONFIG.url || !SUPABASE_CONFIG.anonKey) {
            console.error('❌ بيانات تهيئة Supabase غير كاملة');
            return null;
        }
        
        // إنشاء عميل Supabase
        const client = supabase.createClient(
            SUPABASE_CONFIG.url,
            SUPABASE_CONFIG.anonKey,
            SUPABASE_CONFIG.options
        );
        
        console.log('✅ تم تهيئة عميل Supabase بنجاح');
        
        // اختبار الاتصال البسيط
        testConnection(client);
        
        return client;
        
    } catch (error) {
        console.error('❌ خطأ في تهيئة Supabase:', error);
        return null;
    }
}

// دالة لاختبار الاتصال
async function testConnection(client) {
    try {
        console.log('🔗 اختبار اتصال Supabase...');
        
        const { data, error } = await client
            .from('soil_temperatures')
            .select('count')
            .limit(1);
        
        if (error) {
            console.warn('⚠️ قد يكون هناك مشكلة في الاتصال:', error.message);
            return false;
        }
        
        console.log('✅ اتصال Supabase نشط');
        return true;
        
    } catch (error) {
        console.warn('⚠️ فشل اختبار الاتصال:', error.message);
        return false;
    }
}

// دالة لإعادة الاتصال
async function reconnectSupabase(maxRetries = 3, delay = 1000) {
    console.log('🔄 محاولة إعادة الاتصال بـ Supabase...');
    
    for (let i = 0; i < maxRetries; i++) {
        try {
            const client = initializeSupabase();
            if (client) {
                const isConnected = await testConnection(client);
                if (isConnected) {
                    console.log('✅ تم إعادة الاتصال بنجاح');
                    return client;
                }
            }
            
            if (i < maxRetries - 1) {
                console.log(`⏳ انتظار ${delay}ms قبل المحاولة التالية...`);
                await new Promise(resolve => setTimeout(resolve, delay));
                delay *= 2; // زيادة التأخير بشكل أسي
            }
            
        } catch (error) {
            console.error(`❌ فشل محاولة إعادة الاتصال ${i + 1}:`, error);
        }
    }
    
    console.error('❌ فشل جميع محاولات إعادة الاتصال');
    return null;
}

// دالة للحصول على حالة الاتصال
function getConnectionStatus() {
    return {
        url: SUPABASE_CONFIG.url,
        hasClient: !!window.supabase,
        isOnline: navigator.onLine,
        lastTest: new Date().toISOString()
    };
}

// التهيئة التلقائية
let supabaseClient = null;

try {
    supabaseClient = initializeSupabase();
    
    if (supabaseClient) {
        window.supabase = supabaseClient;
        window.supabaseClient = supabaseClient;
        console.log('✅ تم تهيئة Supabase وتخزينه بشكل عالمي');
    } else {
        console.warn('⚠️ تم تهيئة Supabase بالوضع المحلي فقط');
        window.supabase = {
            from: () => ({
                select: () => ({ data: null, error: { message: 'وضع محلي فقط' } }),
                insert: () => ({ data: null, error: { message: 'وضع محلي فقط' } }),
                update: () => ({ data: null, error: { message: 'وضع محلي فقط' } }),
                delete: () => ({ data: null, error: { message: 'وضع محلي فقط' } })
            })
        };
    }
    
} catch (error) {
    console.error('❌ خطأ فادح في تهيئة Supabase:', error);
    window.supabase = null;
}

// جعل الدوال متاحة عالمياً
window.initializeSupabase = initializeSupabase;
window.reconnectSupabase = reconnectSupabase;
window.getConnectionStatus = getConnectionStatus;
window.testSupabaseConnection = testConnection;

console.log('✅ إعدادات Supabase المحسنة محملة وجاهزة');