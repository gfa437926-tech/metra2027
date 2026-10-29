// js/it-popup.js - نظام الإبلاغ عن مشاكل IT مع إرسال واتساب
console.log('🚀 تحميل نظام الإبلاغ عن مشاكل IT...');

class ITIssuePopup {
    constructor() {
        this.popupWindow = null;
        this.isPopupOpen = false;
        this.whatsappNumber = "0934884157"; // الرقم المطلوب
        this.init();
    }

    // ... باقي الدوال تبقى كما هي ...

    getPopupScript() {
        return `
        // تهيئة النموذج
        document.addEventListener('DOMContentLoaded', function() {
            const form = document.getElementById('itIssueForm');
            const successAlert = document.getElementById('successAlert');
            const errorAlert = document.getElementById('errorAlert');
            const fileUpload = document.getElementById('fileUpload');
            const filePreview = document.getElementById('filePreview');

            // معالجة رفع الملفات
            fileUpload.addEventListener('change', function(e) {
                handleFileUpload(e.target.files);
            });

            // معالجة إرسال النموذج
            form.addEventListener('submit', function(e) {
                e.preventDefault();
                submitIssueReport();
            });

            // تعبئة معلومات المستخدم تلقائياً
            autoFillUserInfo();
        });

        function autoFillUserInfo() {
            try {
                // محاولة جلب بيانات المستخدم من localStorage
                const userData = localStorage.getItem('currentUser');
                if (userData) {
                    const user = JSON.parse(userData);
                    document.getElementById('reporterName').value = 
                        user.first_name + ' ' + user.father_name + ' ' + user.last_name;
                    document.getElementById('reporterStation').value = user.station || '';
                    document.getElementById('reporterEmail').value = user.email || '';
                }
            } catch (error) {
                console.log('لا يمكن تعبئة بيانات المستخدم تلقائياً');
            }
        }

        function handleFileUpload(files) {
            const filePreview = document.getElementById('filePreview');
            filePreview.innerHTML = '';

            if (files.length > 0) {
                filePreview.innerHTML = '<h6>الملفات المرفوعة:</h6>';
                
                Array.from(files).forEach(file => {
                    const fileElement = document.createElement('div');
                    fileElement.className = 'file-item';
                    fileElement.innerHTML = \`
                        <i class="fas fa-file"></i>
                        <span>\${file.name}</span>
                        <small>(\${(file.size / 1024).toFixed(2)} KB)</small>
                    \`;
                    filePreview.appendChild(fileElement);
                });
            }
        }

        function submitIssueReport() {
            const form = document.getElementById('itIssueForm');
            const successAlert = document.getElementById('successAlert');
            const errorAlert = document.getElementById('errorAlert');
            const submitBtn = form.querySelector('button[type="submit"]');
            const originalText = submitBtn.innerHTML;

            // تعطيل الزر أثناء الإرسال
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> جاري الإرسال...';

            // جمع بيانات النموذج
            const formData = {
                reporterName: document.getElementById('reporterName').value,
                reporterStation: document.getElementById('reporterStation').value,
                reporterPhone: document.getElementById('reporterPhone').value,
                reporterEmail: document.getElementById('reporterEmail').value,
                problemType: getProblemTypeText(document.querySelector('input[name="problemType"]:checked').value),
                problemTitle: document.getElementById('problemTitle').value,
                problemDescription: document.getElementById('problemDescription').value,
                problemUrgency: getUrgencyText(document.getElementById('problemUrgency').value),
                browserInfo: document.getElementById('browserInfo').value,
                osInfo: document.getElementById('osInfo').value,
                errorMessage: document.getElementById('errorMessage').value,
                submissionDate: new Date().toLocaleString('ar-SA', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                })
            };

            // التحقق من البيانات المطلوبة
            if (!formData.reporterName || !formData.problemTitle || !formData.problemDescription) {
                showErrorAlert('❌ يرجى ملء جميع الحقول المطلوبة');
                submitBtn.disabled = false;
                submitBtn.innerHTML = originalText;
                return;
            }

            try {
                // إرسال إلى واتساب
                sendToWhatsApp(formData);
                
                // إظهار رسالة النجاح
                showSuccessAlert('✅ تم إرسال التقرير إلى الدعم الفني على واتساب');
                
                // إعادة تعيين النموذج بعد 2 ثانية
                setTimeout(() => {
                    form.reset();
                    document.getElementById('filePreview').innerHTML = '';
                    autoFillUserInfo();
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalText;
                }, 2000);

            } catch (error) {
                console.error('خطأ في الإرسال:', error);
                showErrorAlert('❌ حدث خطأ في الإرسال. يرجى المحاولة مرة أخرى.');
                submitBtn.disabled = false;
                submitBtn.innerHTML = originalText;
            }
        }

        function getProblemTypeText(type) {
            const types = {
                'software': 'مشكلة في البرنامج',
                'network': 'مشكلة في الشبكة',
                'hardware': 'مشكلة في الأجهزة',
                'data': 'مشكلة في البيانات',
                'other': 'مشكلة أخرى'
            };
            return types[type] || type;
        }

        function getUrgencyText(urgency) {
            const levels = {
                'low': 'منخفضة',
                'medium': 'متوسطة',
                'high': 'عالية',
                'critical': 'حرجة'
            };
            return levels[urgency] || urgency;
        }

        function sendToWhatsApp(formData) {
            const phoneNumber = "0934884157";
            
            // بناء رسالة واتساب منسقة
            const message = \`
🚨 *تقرير مشكلة تقنية - الدعم الفني IT*

👤 *المبلغ:* 
\${formData.reporterName}

🏢 *المحطة:* 
\${formData.reporterStation || 'غير محدد'}

📞 *للتواصل:* 
\${formData.reporterPhone || 'غير محدد'}
\${formData.reporterEmail ? '📧 ' + formData.reporterEmail : ''}

🔧 *نوع المشكلة:*
\${formData.problemType}

📋 *عنوان المشكلة:*
\${formData.problemTitle}

🚩 *درجة الأهمية:*
\${formData.problemUrgency}

📝 *وصف المشكلة:*
\${formData.problemDescription}

\${formData.errorMessage ? \`⚠️ *رسائل الخطأ:*\n\${formData.errorMessage}\n\` : ''}

\${formData.browserInfo ? \`🌐 *المتصفح:* \${formData.browserInfo}\n\` : ''}
\${formData.osInfo ? \`💻 *نظام التشغيل:* \${formData.osInfo}\n\` : ''}

🕒 *وقت الإبلاغ:*
\${formData.submissionDate}

_تم الإرسال عبر نظام الإبلاغ التقني_
            \`.trim();

            // ترميز الرسالة للرابط
            const encodedMessage = encodeURIComponent(message);
            const whatsappURL = \`https://wa.me/\${phoneNumber}?text=\${encodedMessage}\`;
            
            // فتح واتساب في نافذة جديدة
            const whatsappWindow = window.open(whatsappURL, '_blank');
            
            // إذا لم تفتح النافذة (متصفح مسدود للنوافذ المنبثقة)
            if (!whatsappWindow) {
                // نسخ الرسالة إلى الحافظة وعرضها للمستخدم
                copyToClipboard(message);
                showInfoAlert('📋 تم نسخ التقرير إلى الحافظة. يرجى لصقه في واتساب يدوياً.');
            }
        }

        function copyToClipboard(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
        }

        function showSuccessAlert(message) {
            const alert = document.getElementById('successAlert');
            const alertText = alert.querySelector('span');
            alertText.textContent = message;
            alert.style.display = 'flex';
            document.getElementById('errorAlert').style.display = 'none';
            
            // إخفاء التنبيه بعد 5 ثوانٍ
            setTimeout(() => {
                alert.style.display = 'none';
            }, 5000);
        }

        function showErrorAlert(message) {
            const alert = document.getElementById('errorAlert');
            const alertText = document.getElementById('errorMessageText');
            alertText.textContent = message;
            alert.style.display = 'flex';
            document.getElementById('successAlert').style.display = 'none';
        }

        function showInfoAlert(message) {
            // إنشاء تنبيه معلومات مؤقت
            const infoAlert = document.createElement('div');
            infoAlert.className = 'alert alert-info';
            infoAlert.innerHTML = \`
                <i class="fas fa-info-circle"></i>
                <span>\${message}</span>
            \`;
            infoAlert.style.cssText = \`
                position: fixed;
                top: 20px;
                left: 50%;
                transform: translateX(-50%);
                z-index: 1060;
                padding: 1rem 1.5rem;
                border-radius: 8px;
                display: flex;
                align-items: center;
                gap: 1rem;
                box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
            \`;
            
            document.body.appendChild(infoAlert);
            
            setTimeout(() => {
                infoAlert.remove();
            }, 5000);
        }

        // منع إغلاق النافذة عند الضغط على Esc
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                e.preventDefault();
                if (confirm('هل تريد إغلاق نافذة الإبلاغ؟')) {
                    window.close();
                }
            }
        });
        `;
    }
}

// إنشاء وتصدير المدير
const itPopupManager = new ITIssuePopup();
window.itPopupManager = itPopupManager;