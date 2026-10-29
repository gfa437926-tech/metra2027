// js/login.js - الملف المحدث والمكتمل
console.log('🚀 تحميل نظام تسجيل الدخول...');

// الانتظار حتى تحميل الصفحة بالكامل
window.addEventListener('DOMContentLoaded', function() {
    console.log('🏠 تهيئة صفحة تسجيل الدخول...');
    initializeLoginPage();
});

function initializeLoginPage() {
    console.log('🔧 بدء تهيئة صفحة التسجيل...');
    
    // تهيئة Supabase أولاً
    initializeSupabase();
    
    // التحقق من الجلسة النشطة
    if (checkExistingSession()) {
        return;
    }
    
    // تهيئة المحطات
    initializeStations();
    
    // إعداد أحداث كلمات المرور
    setupPasswordToggles();
    
    // إعداد أحداث النماذج
    setupFormEvents();
    
    console.log('✅ تم تهيئة صفحة التسجيل بنجاح');
}

function initializeStations() {
    const stationSelect = document.getElementById('station');
    if (stationSelect) {
        stationSelect.innerHTML = '<option value="" selected disabled>اختر محطتك</option>';
        
        window.CONFIG.WEATHER_STATIONS.forEach(station => {
            const option = document.createElement('option');
            option.value = station;
            option.textContent = station;
            stationSelect.appendChild(option);
        });
        console.log('✅ تم تهيئة قائمة المحطات');
    }
}

function setupPasswordToggles() {
    const toggleConfigs = [
        { toggleId: 'loginPasswordToggle', fieldId: 'loginPassword' },
        { toggleId: 'programPasswordToggle', fieldId: 'programPassword' },
        { toggleId: 'passwordToggle', fieldId: 'password' },
        { toggleId: 'confirmPasswordToggle', fieldId: 'confirmPassword' }
    ];

    toggleConfigs.forEach(config => {
        const toggle = document.getElementById(config.toggleId);
        const field = document.getElementById(config.fieldId);
        
        if (toggle && field) {
            toggle.addEventListener('click', function() {
                togglePasswordVisibility(field, this);
            });
        }
    });
    
    setupPasswordValidation();
}

function setupPasswordValidation() {
    const passwordField = document.getElementById('password');
    const confirmPasswordField = document.getElementById('confirmPassword');
    const matchText = document.getElementById('passwordMatchText');
    
    if (passwordField && confirmPasswordField && matchText) {
        const validateHandler = () => validatePasswordMatch();
        passwordField.addEventListener('input', validateHandler);
        confirmPasswordField.addEventListener('input', validateHandler);
    }
}

function validatePasswordMatch() {
    const password = document.getElementById('password')?.value || '';
    const confirmPassword = document.getElementById('confirmPassword')?.value || '';
    const matchText = document.getElementById('passwordMatchText');
    
    if (!matchText) return;
    
    if (confirmPassword === '') {
        matchText.textContent = '';
        matchText.className = 'form-text';
    } else if (password === confirmPassword) {
        matchText.textContent = '✅ كلمات المرور متطابقة';
        matchText.className = 'form-text text-success';
    } else {
        matchText.textContent = '❌ كلمات المرور غير متطابقة';
        matchText.className = 'form-text text-danger';
    }
}

function togglePasswordVisibility(passwordField, toggleElement) {
    const type = passwordField.getAttribute('type') === 'password' ? 'text' : 'password';
    passwordField.setAttribute('type', type);
    
    const icon = toggleElement.querySelector('i');
    if (icon) {
        icon.className = type === 'password' ? 'far fa-eye' : 'far fa-eye-slash';
    }
}

function setupFormEvents() {
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }
    
    const registerForm = document.getElementById('registerForm');
    if (registerForm) {
        registerForm.addEventListener('submit', handleRegister);
    }
    
    const forgotForm = document.getElementById('forgotForm');
    if (forgotForm) {
        forgotForm.addEventListener('submit', handleForgotPassword);
    }
}

async function handleLogin(e) {
    e.preventDefault();
    console.log('🔐 بدء تسجيل الدخول...');
    
    const client = initializeSupabase();
    if (!client) {
        showAlert('loginAlert', '❌ خطأ في الاتصال بالنظام', 'danger');
        return;
    }
    
    const email = document.getElementById('loginEmail').value.trim();
    const password = document.getElementById('loginPassword').value;
    const loginButton = document.getElementById('loginButton');
    const loading = document.getElementById('loginLoading');
    const alertDiv = document.getElementById('loginAlert');
    
    if (!email || !password) {
        showAlert(alertDiv, '❌ يرجى ملء جميع الحقول', 'danger');
        return;
    }
    
    setButtonLoading(loginButton, loading, true);
    clearAlert(alertDiv);
    
    try {
        console.log('📧 البحث عن المستخدم:', email);
        
        const { data: user, error } = await client
            .from('users')
            .select('*')
            .eq('email', email)
            .single();
        
        if (error) {
            console.error('❌ خطأ في البحث:', error);
            if (error.code === 'PGRST116') {
                throw new Error('❌ البريد الإلكتروني أو كلمة المرور غير صحيحة');
            }
            throw new Error('❌ حدث خطأ في الاتصال بالخادم');
        }
        
        if (!user) {
            throw new Error('❌ البريد الإلكتروني أو كلمة المرور غير صحيحة');
        }
        
        console.log('✅ تم العثور على المستخدم:', user.email);
        
        // التحقق من كلمة المرور
        const isPasswordValid = await verifyPassword(password, user.password_hash);
        console.log('🔑 نتيجة التحقق من كلمة المرور:', isPasswordValid);
        
        if (!isPasswordValid) {
            throw new Error('❌ البريد الإلكتروني أو كلمة المرور غير صحيحة');
        }
        
        // التحقق من حالة الحساب
        if (user.status !== 'approved') {
            let message = '⏳ حسابك قيد الانتظار للموافقة. ';
            if (!user.approved_by_station_manager) {
                message += 'بانتظار موافقة رئيس المحطة.';
            } else if (!user.approved_by_system_manager) {
                message += 'بانتظار موافقة مدير النظام.';
            }
            throw new Error(message);
        }
        
        // حفظ بيانات المستخدم في localStorage
        saveUserSession(user);
        console.log('✅ تم تسجيل الدخول بنجاح');
        
        // التوجيه
        redirectUserByRole(user.role);
        
    } catch (error) {
        console.error('❌ خطأ في تسجيل الدخول:', error);
        showAlert(alertDiv, error.message, 'danger');
    } finally {
        setButtonLoading(loginButton, loading, false);
    }
}

// حفظ بيانات المستخدم في التخزين المحلي
function saveUserSession(userData) {
    const userSessionData = {
        id: userData.id,
        email: userData.email,
        role: userData.role,
        station: userData.station,
        first_name: userData.first_name,
        father_name: userData.father_name,
        last_name: userData.last_name,
        phone: userData.phone,
        status: userData.status,
        login_time: Date.now()
    };

    // حفظ في localStorage
    localStorage.setItem('currentUser', JSON.stringify(userSessionData));
    console.log('💾 تم حفظ بيانات المستخدم في localStorage');
}

async function handleRegister(e) {
    e.preventDefault();
    console.log('📝 بدء عملية التسجيل...');
    
    const client = initializeSupabase();
    if (!client) {
        showAlert('registerAlert', '❌ خطأ في الاتصال بالنظام', 'danger');
        return;
    }
    
    const registerButton = document.getElementById('registerButton');
    const loading = document.getElementById('registerLoading');
    const alertDiv = document.getElementById('registerAlert');
    
    const formData = {
        first_name: document.getElementById('firstName').value.trim(),
        father_name: document.getElementById('fatherName').value.trim(),
        last_name: document.getElementById('lastName').value.trim(),
        email: document.getElementById('email').value.trim().toLowerCase(),
        phone: document.getElementById('phone').value.trim(),
        station: document.getElementById('station').value,
        role: document.getElementById('role').value,
        password: document.getElementById('password').value,
        confirmPassword: document.getElementById('confirmPassword').value,
        program_password: document.getElementById('programPassword').value
    };
    
    const validationError = validateRegistrationData(formData);
    if (validationError) {
        showAlert(alertDiv, validationError, 'danger');
        return;
    }
    
    // التحقق من كلمة مرور البرنامج
    if (formData.program_password !== 'meteo2026') {
        showAlert(alertDiv, '❌ كلمة مرور البرنامج غير صحيحة', 'danger');
        return;
    }
    
    const agreeTerms = document.getElementById('agreeTerms');
    if (!agreeTerms?.checked) {
        showAlert(alertDiv, '❌ يجب الموافقة على الشروط والأحكام', 'danger');
        return;
    }
    
    setButtonLoading(registerButton, loading, true);
    clearAlert(alertDiv);
    
    try {
        console.log('🔍 التحقق من البريد الإلكتروني...');
        const { data: existingUser, error: checkError } = await client
            .from('users')
            .select('id')
            .eq('email', formData.email)
            .single();
        
        if (existingUser) {
            throw new Error('❌ البريد الإلكتروني مسجل مسبقاً');
        }
        
        console.log('🔐 تشفير كلمة المرور...');
        const passwordHash = await hashPassword(formData.password);
        
        console.log('💾 حفظ المستخدم في قاعدة البيانات...');
        const { data: newUser, error: insertError } = await client
            .from('users')
            .insert([{
                first_name: formData.first_name,
                father_name: formData.father_name,
                last_name: formData.last_name,
                email: formData.email,
                phone: formData.phone,
                station: formData.station,
                role: formData.role,
                password_hash: passwordHash,
                status: 'pending',
                approved_by_station_manager: false,
                approved_by_system_manager: false,
                created_at: new Date().toISOString()
            }])
            .select()
            .single();
        
        if (insertError) {
            console.error('❌ خطأ في الإدخال:', insertError);
            throw new Error('❌ حدث خطأ في إنشاء الحساب. يرجى المحاولة مرة أخرى.');
        }
        
        console.log('✅ تم إنشاء الحساب بنجاح:', newUser.email);
        showAlert(alertDiv, 
            '✅ تم التسجيل بنجاح!<br>⏳ سيتم مراجعة طلبك من قبل رئيس المحطة ومدير النظام.<br>📧 ستتلقى إشعاراً عند الموافقة على حسابك.', 
            'success'
        );
        
        resetRegistrationForm();
        
    } catch (error) {
        console.error('❌ خطأ في التسجيل:', error);
        showAlert(alertDiv, error.message, 'danger');
    } finally {
        setButtonLoading(registerButton, loading, false);
    }
}

async function handleForgotPassword(e) {
    e.preventDefault();
    console.log('🔓 بدء عملية استعادة كلمة المرور...');
    
    const client = initializeSupabase();
    if (!client) {
        showAlert('forgotAlert', '❌ خطأ في الاتصال بالنظام', 'danger');
        return;
    }
    
    const email = document.getElementById('forgotEmail').value.trim().toLowerCase();
    const phone = document.getElementById('forgotPhone').value.trim();
    const forgotButton = document.getElementById('forgotButton');
    const loading = document.getElementById('forgotLoading');
    const alertDiv = document.getElementById('forgotAlert');
    
    if (!email || !phone) {
        showAlert(alertDiv, '❌ يرجى ملء جميع الحقول', 'danger');
        return;
    }
    
    setButtonLoading(forgotButton, loading, true);
    clearAlert(alertDiv);
    
    try {
        console.log('🔍 البحث عن المستخدم...');
        const { data: user, error } = await client
            .from('users')
            .select('*')
            .eq('email', email)
            .eq('phone', phone)
            .single();
        
        if (error || !user) {
            throw new Error('❌ لا يوجد حساب مرتبط بالبريد الإلكتروني ورقم الهاتف المدخلين');
        }
        
        console.log('✅ تم العثور على المستخدم:', user.email);
        
        // إنشاء كلمة مرور مؤقتة
        const temporaryPassword = generateTemporaryPassword();
        console.log('🔑 كلمة المرور المؤقتة الجديدة:', temporaryPassword);
        
        const passwordHash = await hashPassword(temporaryPassword);
        
        console.log('💾 تحديث كلمة المرور في قاعدة البيانات...');
        const { error: updateError } = await client
            .from('users')
            .update({ 
                password_hash: passwordHash,
                updated_at: new Date().toISOString()
            })
            .eq('id', user.id);
        
        if (updateError) throw updateError;
        
        showAlert(alertDiv, 
            `✅ تم إعادة تعيين كلمة المرور بنجاح!<br>
            <strong>🔑 كلمة المرور الجديدة:</strong> ${temporaryPassword}<br>
            <small class="text-muted">⚠️ يرجى تغييرها بعد تسجيل الدخول للحفاظ على أمان حسابك.</small>`, 
            'success'
        );
        
        document.getElementById('forgotForm').reset();
        
    } catch (error) {
        console.error('❌ خطأ في استعادة كلمة المرور:', error);
        showAlert(alertDiv, error.message, 'danger');
    } finally {
        setButtonLoading(forgotButton, loading, false);
    }
}

// ==================== دوال المساعدة ====================

function validateRegistrationData(formData) {
    if (!formData.first_name || !formData.father_name || !formData.last_name) {
        return '❌ يرجى ملء جميع حقول الاسم';
    }
    
    if (!formData.email || !isValidEmail(formData.email)) {
        return '❌ يرجى إدخال بريد إلكتروني صحيح';
    }
    
    if (!formData.phone) {
        return '❌ يرجى إدخال رقم هاتف';
    }
    
    if (!formData.station) {
        return '❌ يرجى اختيار المحطة';
    }
    
    if (!formData.role) {
        return '❌ يرجى اختيار صفة العمل';
    }
    
    if (!formData.password || formData.password.length < 6) {
        return '❌ كلمة المرور يجب أن تكون至少 6 أحرف';
    }
    
    if (formData.password !== formData.confirmPassword) {
        return '❌ كلمات المرور غير متطابقة';
    }
    
    return null;
}

function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

function setButtonLoading(button, loadingElement, isLoading) {
    if (button && loadingElement) {
        button.disabled = isLoading;
        loadingElement.innerHTML = isLoading ? ' <i class="fas fa-spinner fa-spin"></i>' : '';
    }
}

function clearAlert(alertDiv) {
    if (alertDiv) {
        alertDiv.innerHTML = '';
    }
}

function showAlert(container, message, type) {
    if (!container) return;
    
    container.innerHTML = `
        <div class="alert alert-${type} alert-dismissible fade show" role="alert">
            <div class="d-flex align-items-center">
                <i class="fas ${type === 'success' ? 'fa-check-circle' : 'fa-exclamation-triangle'} me-2"></i>
                <div>${message}</div>
            </div>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    `;
}

function resetRegistrationForm() {
    const form = document.getElementById('registerForm');
    if (form) {
        form.reset();
    }
    
    const matchText = document.getElementById('passwordMatchText');
    if (matchText) {
        matchText.textContent = '';
        matchText.className = 'form-text';
    }
}

function redirectUserByRole(role) {
    const rolePages = {
        'مدير النظام': 'manager-dashboard.html',
        'رئيس محطة': 'station-manager.html',
        'رئيس الاتصالات': 'fix_tel.html',
        'رئيس الورشات': 'fix2.html',
        'مدقق': 'rec_main.html',
        'راصد جوي': 'main.html'
    };
    
    const targetPage = rolePages[role] || 'main.html';
    console.log('🎯 التوجيه إلى:', targetPage, 'للدور:', role);
    window.location.href = targetPage;
}

function checkExistingSession() {
    const currentUser = localStorage.getItem('currentUser');
    
    if (currentUser) {
        try {
            const userData = JSON.parse(currentUser);
            console.log('🔍 تم العثور على جلسة نشطة:', userData.email);
            
            // التحقق من انتهاء الجلسة (24 ساعة)
            const loginTime = userData.login_time;
            if (loginTime && (Date.now() - parseInt(loginTime)) > 24 * 60 * 60 * 1000) {
                console.log('⏰ انتهت مدة الجلسة');
                clearUserSession();
                return false;
            }
            
            redirectUserByRole(userData.role);
            return true;
        } catch (e) {
            console.error('❌ خطأ في تحليل بيانات الجلسة:', e);
            clearUserSession();
        }
    }
    console.log('🔍 لا توجد جلسة نشطة');
    return false;
}

function generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%';
    let password = '';
    for (let i = 0; i < 10; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return password;
}

// ==================== دوال التشفير ====================

async function hashPassword(password) {
    try {
        console.log('🔐 جاري تشفير كلمة المرور...');
        const encoder = new TextEncoder();
        const data = encoder.encode(password);
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        console.log('🔐 كلمة المرور المشفرة:', hashHex);
        return hashHex;
    } catch (error) {
        console.error('❌ خطأ في التشفير:', error);
        // Fallback بسيط للتشفير
        return btoa(encodeURIComponent(password));
    }
}

async function verifyPassword(password, hash) {
    try {
        // إذا كان الهاش من SHA-256
        if (hash && hash.length === 64) {
            const testHash = await hashPassword(password);
            console.log('🔍 مقارنة التشفير SHA-256:', {
                'المدخلة-مشفرة': testHash,
                'في-قاعدة-البيانات': hash,
                'متطابقة': testHash === hash
            });
            return testHash === hash;
        }
        
        // إذا كان الهاش من Base64 (الطريقة القديمة)
        try {
            const decoded = decodeURIComponent(atob(hash));
            console.log('🔍 استخدام الطريقة القديمة للتحقق');
            return decoded === password;
        } catch (e) {
            console.log('🔍 فشل في فك تشفير Base64');
            return false;
        }
    } catch (error) {
        console.error('❌ خطأ في التحقق من كلمة المرور:', error);
        return false;
    }
}

function clearUserSession() {
    localStorage.removeItem('currentUser');
    console.log('🗑️ تم حذف جلسة المستخدم');
}

// جعل الدوال متاحة عالمياً
window.logout = clearUserSession;
window.hashPassword = hashPassword;
window.verifyPassword = verifyPassword;