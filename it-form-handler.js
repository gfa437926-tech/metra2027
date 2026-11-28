// js/it-form-handler.js - نظام معالجة نماذج الإبلاغ عن المشاكل التقنية
console.log('🔄 تحميل نظام معالجة نماذج IT...');

class ITFormHandler {
    constructor() {
        this.bulletinFields = {
            "ساعي سينوب": [
                { name: "وقت الرصد", code: "بدون رمز" },
                { name: "الرطوبة النسبية %", code: "105" },
                { name: "ضغط بخار الماء لأقرب عشر الميلبار", code: "166" },
                { name: "درجة الندى لأقرب عشر (سْ)", code: "103" },
                { name: "ضـغــط المـحـطـــة", code: "106" },
                { name: "الضغط المحول لسطح البحر", code: "107" },
                { name: "درجة الحرارة الجافة", code: "101" },
                { name: "درجة الحرارة الرطبة", code: "102" },
                { name: "اتجاه الرياح السطحية بعشرات الدرجات", code: "112" },
                { name: "سرعة الرياح السطحية لأقرب م/ثا", code: "111" },
                { name: "اتجاه المتوسط الساعي للرياح السطحية", code: "182" },
                { name: "سرعة المتوسط الساعي للرياح السطحية", code: "181" },
                { name: "الرؤية السطحية الأفقية بمئات الأمتار", code: "110" },
                { name: "الطقس الحاضر", code: "167" },
                { name: "الطقس الغابر", code: "183" },
                { name: "التغطية الكلية للسحب", code: "114" }
            ],
            "يومي مناخي": [
                { name: "يوم الرصد", code: "بدون رمز" },
                { name: "القيمة الصغرى في النهايات", code: "003" },
                { name: "القيمة العظمى في النهايات", code: "002" },
                { name: "الهطول لأقرب عشر مم", code: "005" },
                { name: "الأثـــر", code: "717" },
                { name: "أكبر سماكة ثلج لأقرب سم", code: "049" },
                { name: "عواصف رعدية", code: "030" },
                { name: "برد", code: "031" },
                { name: "ثلج", code: "035" },
                { name: "مطر", code: "029" }
            ],
            "بيانات زراعية": [
                { name: "الرصد", code: "بدون رمز" },
                { name: "الرطوبة النسبية %", code: "105" },
                { name: "ضغط بخار الماء لأقرب عشر الميلبار", code: "166" },
                { name: "درجة الندى لأقرب عشر (سْ)", code: "103" },
                { name: "درجة الحرارة الجافة", code: "101" },
                { name: "درجة الحرارة الرطبة", code: "102" }
            ],
            "درجات الحرارة التربة": [
                { name: "الرصد", code: "بدون رمز" },
                { name: "درجة حرارة التربة على عمق 5سم", code: "72" },
                { name: "درجة حرارة التربة على عمق 10سم", code: "73" },
                { name: "درجة حرارة التربة على عمق 20سم", code: "74" },
                { name: "درجة حرارة التربة على عمق 50سم", code: "75" }
            ],
            "النشرات الزراعية الشهرية": [
                { name: "يوم الرصد", code: "بدون رمز" },
                { name: "معدل درجة حرارة الهواء", code: "بدون رمز" },
                { name: "القيمة العظمى لدرجة حرارة الهواء", code: "بدون رمز" },
                { name: "القيمة الصغرى لدرجة حرارة الهواء", code: "بدون رمز" },
                { name: "القيمة الصغرى على ارتفاع 2م", code: "بدون رمز" }
            ]
        };

        this.validationRules = {
            reporterName: { required: true, minLength: 2, maxLength: 100 },
            reporterPosition: { required: true, minLength: 2, maxLength: 100 },
            reporterPhone: { required: true, pattern: /^09\d{8}$/ },
            bulletinType: { required: true },
            problemField: { required: true },
            problemType: { required: true },
            problemDescription: { required: true, minLength: 10, maxLength: 1000 },
            correctFieldName: { required: true, minLength: 2 },
            correctUnit: { required: true, minLength: 1 },
            inputMask: { required: true, minLength: 3 },
            minValue: { required: true, number: true },
            maxValue: { required: true, number: true },
            missingConditions: { required: true, minLength: 10 },
            extraFieldDetails: { required: true, minLength: 10 },
            missingFieldDetails: { required: true, minLength: 10 },
            otherProblemDetails: { required: true, minLength: 10 }
        };

        this.whatsAppSender = new WhatsAppSender();
        this.init();
    }

    init() {
        this.bindEvents();
        this.setCurrentDateTime();
        console.log('✅ تم تهيئة نظام معالجة النماذج بنجاح');
    }

    bindEvents() {
        // أحداث تغيير نوع النشرة
        document.getElementById('bulletinType')?.addEventListener('change', (e) => {
            this.handleBulletinTypeChange(e.target.value);
        });

        // أحداث تغيير نوع المشكلة
        document.getElementById('problemType')?.addEventListener('change', (e) => {
            this.handleProblemTypeChange(e.target.value);
        });

        // حدث إرسال التقرير
        document.getElementById('sendReport')?.addEventListener('click', () => {
            this.handleReportSubmission();
        });

        // أحداث التحقق أثناء الكتابة
        this.setupRealTimeValidation();

        // معالج النموذج المنبثق
        document.getElementById('submitSoftwareProblem')?.addEventListener('click', () => {
            this.handleSoftwareProblemSubmission();
        });
    }

    handleBulletinTypeChange(selectedBulletin) {
        const problemFieldSelect = document.getElementById('problemField');
        const availableFieldsDiv = document.getElementById('availableFields');
        
        if (!problemFieldSelect) return;
        
        problemFieldSelect.innerHTML = '<option value="">-- اختر الحقل --</option>';
        
        if (selectedBulletin && this.bulletinFields[selectedBulletin]) {
            this.bulletinFields[selectedBulletin].forEach(field => {
                const option = document.createElement('option');
                option.value = field.name;
                option.textContent = field.name;
                problemFieldSelect.appendChild(option);
            });
            
            this.displayAvailableFields(selectedBulletin);
        } else {
            availableFieldsDiv.innerHTML = '<p style="text-align: center; color: #666; padding: 20px;">يرجى اختيار نوع النشرة أولاً لعرض الحقول المتاحة</p>';
        }
        
        this.updateProgress(1);
        this.validateField(problemFieldSelect);
    }

    displayAvailableFields(bulletinType) {
        const fields = this.bulletinFields[bulletinType];
        const availableFieldsDiv = document.getElementById('availableFields');
        if (!availableFieldsDiv) return;
        
        let html = '';
        
        fields.forEach(field => {
            html += `
                <div class="field-group">
                    <div class="field-title">${field.name}</div>
                    <div class="field-code">رمز العنصر: ${field.code}</div>
                </div>
            `;
        });
        
        availableFieldsDiv.innerHTML = html;
    }

    handleProblemTypeChange(problemType) {
        const problemDetailsDiv = document.getElementById('problemDetails');
        if (!problemDetailsDiv) return;
        
        problemDetailsDiv.innerHTML = '';
        problemDetailsDiv.classList.add('hidden');
        
        if (problemType) {
            problemDetailsDiv.classList.remove('hidden');
            this.renderProblemDetails(problemType);
        }
        
        this.updateProgress(2);
    }

    renderProblemDetails(problemType) {
        const problemDetailsDiv = document.getElementById('problemDetails');
        if (!problemDetailsDiv) return;
        
        let detailsHTML = '';
        
        const templates = {
            'اسم الحقل': `
                <div class="form-group">
                    <label for="correctFieldName" class="form-label">الاسم الحرفي المطلوب للحقل *</label>
                    <input type="text" id="correctFieldName" name="correctFieldName" class="form-control" required
                           data-validation="required,minLength:2">
                    <div class="validation-feedback"></div>
                </div>
            `,
            'الوحدة المستخدمة': `
                <div class="form-group">
                    <label for="correctUnit" class="form-label">الوحدة المستخدمة للحقل *</label>
                    <input type="text" id="correctUnit" name="correctUnit" class="form-control" required
                           data-validation="required,minLength:1">
                    <div class="validation-feedback"></div>
                </div>
            `,
            'قناع الإدخال': `
                <div class="form-group">
                    <label for="inputMask" class="form-label">قناع الإدخال (مثال: dd.d) *</label>
                    <input type="text" id="inputMask" name="inputMask" class="form-control" 
                           placeholder="أدخل قناع الإدخال كامل مع فواصل" required
                           data-validation="required,minLength:3">
                    <div class="validation-feedback"></div>
                </div>
            `,
            'قيمة الحقل': `
                <div class="form-group">
                    <label for="minValue" class="form-label">الحد الأدنى للحقل *</label>
                    <input type="number" id="minValue" name="minValue" class="form-control" step="any" required
                           data-validation="required,number">
                    <div class="validation-feedback"></div>
                </div>
                <div class="form-group">
                    <label for="maxValue" class="form-label">الحد الأعلى للحقل *</label>
                    <input type="number" id="maxValue" name="maxValue" class="form-control" step="any" required
                           data-validation="required,number">
                    <div class="validation-feedback"></div>
                </div>
            `,
            'الشروط الخاصة بالحقل': `
                <div class="form-group">
                    <label for="missingConditions" class="form-label">الشروط المفقودة للحقل *</label>
                    <textarea id="missingConditions" name="missingConditions" class="form-control" required
                              data-validation="required,minLength:10"></textarea>
                    <div class="validation-feedback"></div>
                </div>
            `,
            'حقل زائد': `
                <div class="form-group">
                    <label for="extraFieldDetails" class="form-label">تفاصيل الحقل الزائد *</label>
                    <textarea id="extraFieldDetails" name="extraFieldDetails" class="form-control" required
                              data-validation="required,minLength:10"></textarea>
                    <div class="validation-feedback"></div>
                </div>
            `,
            'حقل ناقص': `
                <div class="form-group">
                    <label for="missingFieldDetails" class="form-label">تفاصيل الحقل الناقص *</label>
                    <textarea id="missingFieldDetails" name="missingFieldDetails" class="form-control" required
                              data-validation="required,minLength:10"></textarea>
                    <div class="validation-feedback"></div>
                </div>
            `,
            'مشكلة أخرى': `
                <div class="form-group">
                    <label for="otherProblemDetails" class="form-label">تفاصيل المشكلة الأخرى *</label>
                    <textarea id="otherProblemDetails" name="otherProblemDetails" class="form-control" required
                              data-validation="required,minLength:10"></textarea>
                    <div class="validation-feedback"></div>
                </div>
            `
        };
        
        detailsHTML = templates[problemType] || '';
        problemDetailsDiv.innerHTML = detailsHTML;
        
        // إعادة إعداد التحقق للعناصر الجديدة
        this.setupRealTimeValidation();
    }

    setupRealTimeValidation() {
        const inputs = document.querySelectorAll('input, textarea, select');
        inputs.forEach(input => {
            input.addEventListener('blur', () => this.validateField(input));
            input.addEventListener('input', () => this.clearFieldError(input));
        });
    }

    validateField(field) {
        const rules = this.getValidationRules(field);
        const value = field.value.trim();
        const feedbackElement = field.parentNode.querySelector('.validation-feedback');
        
        if (!rules) return true;

        let isValid = true;
        let errorMessage = '';

        if (rules.required && !value) {
            isValid = false;
            errorMessage = 'هذا الحقل مطلوب';
        } else if (rules.minLength && value.length < rules.minLength) {
            isValid = false;
            errorMessage = `الحد الأدنى للحروف هو ${rules.minLength}`;
        } else if (rules.maxLength && value.length > rules.maxLength) {
            isValid = false;
            errorMessage = `الحد الأقصى للحروف هو ${rules.maxLength}`;
        } else if (rules.pattern && !rules.pattern.test(value)) {
            isValid = false;
            errorMessage = 'التنسيق غير صحيح';
        } else if (rules.number && isNaN(value)) {
            isValid = false;
            errorMessage = 'يجب إدخال رقم صحيح';
        }

        this.setFieldValidationState(field, isValid, errorMessage, feedbackElement);
        return isValid;
    }

    getValidationRules(field) {
        const fieldName = field.name || field.id;
        return this.validationRules[fieldName] || this.parseDataValidation(field);
    }

    parseDataValidation(field) {
        const validationAttr = field.getAttribute('data-validation');
        if (!validationAttr) return null;

        const rules = {};
        const validations = validationAttr.split(',');

        validations.forEach(validation => {
            if (validation === 'required') rules.required = true;
            if (validation === 'number') rules.number = true;
            if (validation.startsWith('minLength:')) {
                rules.minLength = parseInt(validation.split(':')[1]);
            }
            if (validation.startsWith('maxLength:')) {
                rules.maxLength = parseInt(validation.split(':')[1]);
            }
            if (validation.startsWith('pattern:')) {
                rules.pattern = new RegExp(validation.split(':')[1]);
            }
        });

        return rules;
    }

    setFieldValidationState(field, isValid, errorMessage, feedbackElement) {
        field.classList.remove('is-valid', 'is-invalid');
        
        if (isValid) {
            field.classList.add('is-valid');
            if (feedbackElement) feedbackElement.textContent = '';
        } else {
            field.classList.add('is-invalid');
            if (feedbackElement) feedbackElement.textContent = errorMessage;
        }
    }

    clearFieldError(field) {
        field.classList.remove('is-invalid');
        const feedbackElement = field.parentNode.querySelector('.validation-feedback');
        if (feedbackElement) feedbackElement.textContent = '';
    }

    validateForm() {
        const fields = document.querySelectorAll('#problemReportForm [required]');
        let isValid = true;
        let firstInvalidField = null;

        fields.forEach(field => {
            if (!this.validateField(field)) {
                isValid = false;
                if (!firstInvalidField) {
                    firstInvalidField = field;
                }
            }
        });

        if (firstInvalidField) {
            firstInvalidField.scrollIntoView({ behavior: 'smooth', block: 'center' });
            firstInvalidField.focus();
        }

        return isValid;
    }

    async handleReportSubmission() {
        if (!this.validateForm()) {
            this.showNotification('يرجى تصحيح الأخطاء في النموذج قبل الإرسال', 'error');
            return;
        }
        
        const sendReportBtn = document.getElementById('sendReport');
        const sendingMessage = document.getElementById('sendingMessage');
        const sendingStatus = document.getElementById('sendingStatus');
        
        if (!sendReportBtn || !sendingMessage || !sendingStatus) return;
        
        // تعطيل الزر أثناء الإرسال
        sendReportBtn.disabled = true;
        sendReportBtn.innerHTML = '<div class="loading"></div> جاري الإرسال...';
        
        // إظهار رسالة الإرسال
        sendingMessage.classList.remove('hidden');
        sendingStatus.textContent = 'جاري تحضير الرسالة...';
        
        try {
            // محاكاة عملية الإرسال
            await this.simulateSendingProcess(sendingStatus);
            
            // إرسال التقرير فعلياً
            const result = await this.sendWhatsAppReport();
            
            this.showNotification(result.message, result.success ? 'success' : 'success');
            
            // إعادة تعيين النموذب بعد 3 ثوانٍ
            setTimeout(() => {
                this.resetForm();
                sendingMessage.classList.add('hidden');
            }, 3000);
            
        } catch (error) {
            console.error('Error sending report:', error);
            this.showNotification('حدث خطأ أثناء الإرسال. يرجى المحاولة مرة أخرى.', 'error');
            sendReportBtn.disabled = false;
            sendReportBtn.innerHTML = '<i class="fab fa-whatsapp"></i> إرسال التقرير عبر واتساب';
            sendingMessage.classList.add('hidden');
        }
    }

    async simulateSendingProcess(sendingStatus) {
        return new Promise((resolve) => {
            setTimeout(() => {
                sendingStatus.textContent = 'جاري إنشاء محتوى التقرير...';
                
                setTimeout(() => {
                    sendingStatus.textContent = 'جاري فتح واتساب...';
                    resolve();
                }, 1000);
            }, 1000);
        });
    }

    async sendWhatsAppReport() {
        const reportData = this.generateReportData();
        return await this.whatsAppSender.sendReport(reportData);
    }

    generateReportData() {
        const data = {
            reporterName: document.getElementById('reporterName').value,
            reporterPosition: document.getElementById('reporterPosition').value,
            reporterPhone: document.getElementById('reporterPhone').value,
            bulletinType: document.getElementById('bulletinType').value,
            problemField: document.getElementById('problemField').value,
            problemType: document.getElementById('problemType').value,
            problemDescription: document.getElementById('problemDescription').value,
            problemUrgency: document.getElementById('problemUrgency').value,
            additionalDetails: ''
        };
        
        // إضافة البيانات الإضافية حسب نوع المشكلة
        switch(data.problemType) {
            case 'اسم الحقل':
                data.additionalDetails = `الاسم المطلوب: ${document.getElementById('correctFieldName')?.value || ''}`;
                break;
            case 'الوحدة المستخدمة':
                data.additionalDetails = `الوحدة المطلوبة: ${document.getElementById('correctUnit')?.value || ''}`;
                break;
            case 'قناع الإدخال':
                data.additionalDetails = `قناع الإدخال: ${document.getElementById('inputMask')?.value || ''}`;
                break;
            case 'قيمة الحقل':
                data.additionalDetails = `الحد الأدنى: ${document.getElementById('minValue')?.value || ''} | الحد الأعلى: ${document.getElementById('maxValue')?.value || ''}`;
                break;
            case 'الشروط الخاصة بالحقل':
                data.additionalDetails = `الشروط المفقودة: ${document.getElementById('missingConditions')?.value || ''}`;
                break;
            case 'حقل زائد':
                data.additionalDetails = `تفاصيل الحقل الزائد: ${document.getElementById('extraFieldDetails')?.value || ''}`;
                break;
            case 'حقل ناقص':
                data.additionalDetails = `تفاصيل الحقل الناقص: ${document.getElementById('missingFieldDetails')?.value || ''}`;
                break;
            case 'مشكلة أخرى':
                data.additionalDetails = `تفاصيل إضافية: ${document.getElementById('otherProblemDetails')?.value || ''}`;
                break;
        }
        
        return data;
    }

    handleSoftwareProblemSubmission() {
        const modal = bootstrap.Modal.getInstance(document.getElementById('softwareModal'));
        if (modal) modal.hide();
        this.showNotification('تم إرسال بلاغ مشكلة البرنامج بنجاح!', 'success');
    }

    showNotification(message, type) {
        const notification = document.getElementById('notification');
        const notificationText = document.getElementById('notificationText');
        
        if (!notification || !notificationText) return;
        
        notificationText.textContent = message;
        notification.className = `notification ${type}`;
        notification.classList.add('show');
        
        setTimeout(() => {
            notification.classList.remove('show');
        }, 5000);
    }

    updateProgress(step) {
        const progressBar = document.querySelector('.progress-bar');
        const steps = document.querySelectorAll('.step');
        
        if (progressBar) {
            progressBar.style.width = `${(step / 3) * 100}%`;
        }
        
        steps.forEach((s, index) => {
            if (index < step) {
                s.classList.add('active');
            } else {
                s.classList.remove('active');
            }
        });
    }

    resetForm() {
        const form = document.getElementById('problemReportForm');
        if (!form) return;
        
        form.reset();
        document.getElementById('problemDetails').classList.add('hidden');
        document.getElementById('availableFields').innerHTML = '<p style="text-align: center; color: #666; padding: 20px;">يرجى اختيار نوع النشرة أولاً لعرض الحقول المتاحة</p>';
        
        // إعادة تمكين زر الإرسال
        const sendReportBtn = document.getElementById('sendReport');
        if (sendReportBtn) {
            sendReportBtn.disabled = false;
            sendReportBtn.innerHTML = '<i class="fab fa-whatsapp"></i> إرسال التقرير عبر واتساب';
        }
        
        this.updateProgress(0);
        
        // التمرير إلى الأعلى
        window.scrollTo({ top: 0, behavior: 'smooth' });
        
        this.showNotification('تم إعادة تعيين النموذج بنجاح', 'success');
    }

    setCurrentDateTime() {
        const lastLoginElement = document.getElementById('lastLogin');
        if (lastLoginElement) {
            lastLoginElement.textContent = new Date().toLocaleDateString('ar-SA') + ' - ' + new Date().toLocaleTimeString('ar-SA');
        }
    }

    // دالة للمساعدة في تصحيح الأخطاء
    debugForm() {
        const formData = this.generateReportData();
        console.log('📋 بيانات النموذج:', formData);
        console.log('🔧 حالة النظام:', this.whatsAppSender.getSystemStatus());
        
        const errors = [];
        const fields = document.querySelectorAll('#problemReportForm [required]');
        fields.forEach(field => {
            if (!this.validateField(field)) {
                errors.push({
                    field: field.name || field.id,
                    value: field.value,
                    valid: false
                });
            }
        });
        
        console.log('❌ الأخطاء:', errors);
        return { formData, errors, systemStatus: this.whatsAppSender.getSystemStatus() };
    }
}

// إنشاء كائن المعالج عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    window.itFormHandler = new ITFormHandler();
    console.log('✅ تم تحميل نظام معالجة نماذج IT بنجاح');
    
    // إضافة دالة التصحيح للاستخدام في وحدة التحكم
    window.debugForm = () => window.itFormHandler.debugForm();
});