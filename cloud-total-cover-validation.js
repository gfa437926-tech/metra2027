// cloud-total-cover-dropdown.js - نظام التغطية الكلية مع خيارات منسدلة

class CloudTotalCoverDropdown {
    constructor() {
        this.cloudLayers = [
            { id: 'cloud1', amount: 'cloud1Amount', type: 'cloud1Type', height: 'cloud1Height' },
            { id: 'cloud2', amount: 'cloud2Amount', type: 'cloud2Type', height: 'cloud2Height' },
            { id: 'cloud3', amount: 'cloud3Amount', type: 'cloud3Type', height: 'cloud3Height' },
            { id: 'cloud4', amount: 'cloud4Amount', type: 'cloud4Type', height: 'cloud4Height' }
        ];
        
        this.init();
    }

    init() {
        console.log('☁️ بدء تهيئة نظام التغطية الكلية مع الخيارات المنسدلة...');
        
        this.setupDropdownEvents();
        this.setupHashSupport();
        this.setupCoverageSumValidation();
        
        // التحقق الأولي
        this.validateTotalCover();
        
        console.log('✅ نظام التغطية الكلية مع الخيارات المنسدلة جاهز');
    }

    setupDropdownEvents() {
        const totalCoverSelect = document.getElementById('totalCloudCover');
        if (!totalCoverSelect) {
            console.error('❌ حقل التغطية الكلية للسحب غير موجود');
            return;
        }
        
        // إضافة معالج الأحداث
        totalCoverSelect.addEventListener('change', (e) => {
            this.handleTotalCoverChange(e.target);
        });
        
        // المعالجة عند التحميل إذا كانت هناك قيمة مختارة
        if (totalCoverSelect.value) {
            this.handleTotalCoverChange(totalCoverSelect);
        }
        
        console.log('✅ تم إعداد الخيارات المنسدلة للتغطية الكلية');
    }

    handleTotalCoverChange(select) {
        const value = select.value;
        
        console.log(`☁️ تغيير التغطية الكلية إلى: ${value}`);
        
        switch(value) {
            case '9':
                this.handleSkyObscured(select);
                break;
            case '0':
                this.handleSkyClear(select);
                break;
            case '#':
                this.handleHashInput(select);
                break;
            case '':
                // لا شيء إذا كان فارغاً
                break;
            default:
                if (value >= 1 && value <= 8) {
                    this.handleNormalCover(select, value);
                }
                break;
        }
        
        // تحديث التحقق
        this.validateTotalCoverField(select);
    }

    handleSkyObscured(select) {
        console.log('🌫️ السماء مغطاة تماماً (9) - إلغاء جميع حقول السحب');
        
        // 1. تعطيل وإخفاء جميع حقول السحب
        this.disableAllCloudFields();
        
        // 2. تعطيل مجاميع التغطية
        this.disableCoverageSums();
        
        // 3. إضافة مؤثرات بصرية
        this.addSkyObscuredEffects();
        
        // 4. إظهار رسالة توضيحية
        this.showSkyObscuredMessage(select);
        
        // 5. تحديث حالة التحقق
        this.showTotalCoverValidation(select, true);
    }

    disableAllCloudFields() {
        console.log('🔒 تعطيل جميع حقول السحب...');
        
        this.cloudLayers.forEach(layer => {
            const amountField = document.getElementById(layer.amount);
            const typeField = document.getElementById(layer.type);
            const heightField = document.getElementById(layer.height);
            
            // تعطيل وإخفاء حقول كمية السحب
            if (amountField) {
                amountField.value = '/';
                amountField.disabled = true;
                amountField.readOnly = true;
                amountField.classList.add('disabled-field', 'cloud-field-obscured');
                
                // إضافة أيقونة توضيحية
                this.addDisabledIcon(amountField, 'مغطاة');
            }
            
            // إخفاء حقول النوع
            if (typeField) {
                const typeCardField = typeField.closest('.card-field');
                if (typeCardField) {
                    typeCardField.style.display = 'none';
                }
                typeField.value = '/';
                typeField.disabled = true;
                typeField.classList.add('disabled-field');
            }
            
            // إخفاء حقول الارتفاع
            if (heightField) {
                const heightCardField = heightField.closest('.card-field');
                if (heightCardField) {
                    heightCardField.style.display = 'none';
                }
                heightField.value = '';
                heightField.disabled = true;
                heightField.classList.add('disabled-field');
            }
        });
        
        // إخفاء عناوين الطبقات
        this.hideCloudLayerTitles();
    }

    addDisabledIcon(field, text) {
        // إزالة أي أيقونات سابقة
        const existingIcon = field.parentNode.querySelector('.field-status-icon');
        if (existingIcon) {
            existingIcon.remove();
        }
        
        // إضافة أيقونة جديدة
        const icon = document.createElement('span');
        icon.className = 'field-status-icon';
        icon.innerHTML = `
            <span class="badge bg-warning text-dark ms-2">
                <i class="fas fa-ban me-1"></i>${text}
            </span>
        `;
        
        field.parentNode.appendChild(icon);
    }

    hideCloudLayerTitles() {
        const layerTitles = document.querySelectorAll('.cloud-layer h5');
        layerTitles.forEach(title => {
            title.classList.add('text-muted', 'text-decoration-line-through');
            title.innerHTML = `<i class="fas fa-ban me-2"></i>${title.textContent}`;
        });
    }

    showCloudLayerTitles() {
        const layerTitles = document.querySelectorAll('.cloud-layer h5');
        layerTitles.forEach(title => {
            title.classList.remove('text-muted', 'text-decoration-line-through');
            title.innerHTML = title.textContent.replace('☒ ', '').replace('✗ ', '');
        });
    }

    disableCoverageSums() {
        const cover12Field = document.getElementById('cover12');
        const cover123Field = document.getElementById('cover123');
        
        if (cover12Field) {
            cover12Field.value = '/';
            cover12Field.disabled = true;
            cover12Field.classList.add('disabled-field');
        }
        
        if (cover123Field) {
            cover123Field.value = '/';
            cover123Field.disabled = true;
            cover123Field.classList.add('disabled-field');
        }
    }

    addSkyObscuredEffects() {
        // إضافة مؤثرات بصرية لجميع أقسام السحب
        const cloudSection = document.querySelector('.form-section:has(#totalCloudCover)');
        if (cloudSection) {
            cloudSection.classList.add('sky-obscured-section');
            cloudSection.style.transition = 'all 0.5s ease';
            cloudSection.style.backgroundColor = '#fff3cd';
            cloudSection.style.borderColor = '#ffc107';
            cloudSection.style.borderWidth = '2px';
        }
        
        // إضافة مؤثر للقائمة المنسدلة
        const selectElement = document.getElementById('totalCloudCover');
        if (selectElement) {
            selectElement.classList.add('sky-obscured-select');
            selectElement.style.backgroundColor = '#fff3cd';
            selectElement.style.borderColor = '#ffc107';
            selectElement.style.fontWeight = 'bold';
        }
    }

    removeSkyObscuredEffects() {
        // إزالة المؤثرات البصرية
        const cloudSection = document.querySelector('.form-section:has(#totalCloudCover)');
        if (cloudSection) {
            cloudSection.classList.remove('sky-obscured-section');
            cloudSection.style.backgroundColor = '';
            cloudSection.style.borderColor = '';
            cloudSection.style.borderWidth = '';
        }
        
        // إزالة المؤثرات من القائمة المنسدلة
        const selectElement = document.getElementById('totalCloudCover');
        if (selectElement) {
            selectElement.classList.remove('sky-obscured-select');
            selectElement.style.backgroundColor = '';
            selectElement.style.borderColor = '';
            selectElement.style.fontWeight = '';
        }
    }

    handleSkyClear(select) {
        console.log('☀️ السماء صافية (0) - تفعيل جميع الحقول');
        
        // 1. إزالة المؤثرات
        this.removeSkyObscuredEffects();
        
        // 2. تفعيل جميع حقول السحب
        this.enableAllCloudFields();
        
        // 3. تفعيل مجاميع التغطية
        this.enableCoverageSums();
        
        // 4. إظهار رسالة
        this.showNotification('السماء صافية - يمكنك إدخال بيانات السحب', 'success');
        
        // 5. تحديث حالة التحقق
        this.showTotalCoverValidation(select, true);
    }

    enableAllCloudFields() {
        console.log('🔓 تفعيل جميع حقول السحب...');
        
        this.cloudLayers.forEach(layer => {
            const amountField = document.getElementById(layer.amount);
            const typeField = document.getElementById(layer.type);
            const heightField = document.getElementById(layer.height);
            
            // تفعيل حقول كمية السحب
            if (amountField) {
                amountField.value = '';
                amountField.disabled = false;
                amountField.readOnly = false;
                amountField.classList.remove('disabled-field', 'cloud-field-obscured');
                
                // إزالة الأيقونة
                const icon = amountField.parentNode.querySelector('.field-status-icon');
                if (icon) icon.remove();
            }
            
            // إظهار حقول النوع
            if (typeField) {
                const typeCardField = typeField.closest('.card-field');
                if (typeCardField) {
                    typeCardField.style.display = 'block';
                }
                typeField.value = '';
                typeField.disabled = false;
                typeField.classList.remove('disabled-field');
            }
            
            // إظهار حقول الارتفاع
            if (heightField) {
                const heightCardField = heightField.closest('.card-field');
                if (heightCardField) {
                    heightCardField.style.display = 'block';
                }
                heightField.value = '';
                heightField.disabled = false;
                heightField.classList.remove('disabled-field');
            }
        });
        
        // إظهار عناوين الطبقات
        this.showCloudLayerTitles();
    }

    enableCoverageSums() {
        const cover12Field = document.getElementById('cover12');
        const cover123Field = document.getElementById('cover123');
        
        if (cover12Field) {
            cover12Field.value = '';
            cover12Field.disabled = false;
            cover12Field.classList.remove('disabled-field');
        }
        
        if (cover123Field) {
            cover123Field.value = '';
            cover123Field.disabled = false;
            cover123Field.classList.remove('disabled-field');
        }
    }

    handleNormalCover(select, value) {
        console.log(`☁️ التغطية الكلية: ${value}/8`);
        
        // إزالة المؤثرات
        this.removeSkyObscuredEffects();
        
        // تفعيل جميع الحقول
        this.enableAllCloudFields();
        
        // تحديث حالة التحقق
        this.showTotalCoverValidation(select, true);
        
        // إظهار رسالة إذا كانت التغطية عالية
        if (parseInt(value) >= 6) {
            this.showNotification(`تغطية سحب عالية: ${value}/8`, 'info');
        }
    }

    handleHashInput(select) {
        console.log('❓ بيانات غير متوفرة (#)');
        
        // إزالة المؤثرات
        this.removeSkyObscuredEffects();
        
        // تفعيل الحقول مع وضع # في الحقول الفارغة
        this.enableCloudFieldsWithHash();
        
        // تحديث حالة التحقق
        this.showTotalCoverValidation(select, true);
        
        this.showNotification('بيانات غير متوفرة - يمكنك إدخال # في الحقول الأخرى', 'info');
    }

    enableCloudFieldsWithHash() {
        this.cloudLayers.forEach(layer => {
            const amountField = document.getElementById(layer.amount);
            const typeField = document.getElementById(layer.type);
            const heightField = document.getElementById(layer.height);
            
            // إذا كان الحقل فارغاً، ضع #
            if (amountField && !amountField.value.trim() && amountField.value !== '/') {
                amountField.value = '#';
                amountField.classList.add('has-hash');
            }
            
            if (typeField && !typeField.value.trim() && typeField.value !== '/') {
                typeField.value = '#';
                typeField.classList.add('has-hash');
            }
            
            if (heightField && !heightField.value.trim()) {
                heightField.value = '#';
                heightField.classList.add('has-hash');
            }
            
            // تفعيل الحقول
            [amountField, typeField, heightField].forEach(field => {
                if (field) {
                    field.disabled = false;
                    field.readOnly = false;
                    field.classList.remove('disabled-field', 'cloud-field-obscured');
                }
            });
        });
        
        // تفعيل مجاميع التغطية
        const cover12Field = document.getElementById('cover12');
        const cover123Field = document.getElementById('cover123');
        
        if (cover12Field && !cover12Field.value.trim() && cover12Field.value !== '/') {
            cover12Field.value = '#';
            cover12Field.classList.add('has-hash');
        }
        
        if (cover123Field && !cover123Field.value.trim() && cover123Field.value !== '/') {
            cover123Field.value = '#';
            cover123Field.classList.add('has-hash');
        }
        
        [cover12Field, cover123Field].forEach(field => {
            if (field) {
                field.disabled = false;
                field.readOnly = false;
                field.classList.remove('disabled-field');
            }
        });
    }

    validateTotalCoverField(select) {
        const value = select.value;
        const isValid = value !== '' && value !== null;
        
        if (isValid) {
            this.showTotalCoverValidation(select, true);
        } else {
            this.showTotalCoverValidation(select, false, 'يجب اختيار قيمة');
        }
        
        return isValid;
    }

    validateTotalCover() {
        const totalCoverSelect = document.getElementById('totalCloudCover');
        if (totalCoverSelect) {
            this.validateTotalCoverField(totalCoverSelect);
        }
    }

    setupHashSupport() {
        // لا تحتاج معالجة خاصة للـ # في القائمة المنسدلة
        console.log('✅ دعم # مضمن في القائمة المنسدلة');
    }

    setupCoverageSumValidation() {
        const cover12Field = document.getElementById('cover12');
        const cover123Field = document.getElementById('cover123');
        
        if (cover12Field) {
            cover12Field.addEventListener('blur', () => {
                this.validateCoverageSum(cover12Field);
            });
        }
        
        if (cover123Field) {
            cover123Field.addEventListener('blur', () => {
                this.validateCoverageSum(cover123Field);
            });
        }
    }

    validateCoverageSum(field) {
        const value = field.value.trim();
        
        if (value === '' || value === '#' || value === '/') {
            this.showCoverageValidation(field, true);
            return true;
        }
        
        const numValue = parseInt(value);
        const isValid = !isNaN(numValue) && numValue >= 0 && numValue <= 8;
        
        if (isValid) {
            this.showCoverageValidation(field, true);
        } else {
            this.showCoverageValidation(field, false, 'يجب أن تكون القيمة بين 0-8 أو #');
        }
        
        return isValid;
    }

    showTotalCoverValidation(select, isValid, errorMessage = '') {
        if (isValid) {
            select.classList.remove('is-invalid');
            select.classList.add('is-valid');
            
            const errorElement = document.getElementById('totalCloudCoverError');
            if (errorElement) errorElement.style.display = 'none';
            
            const successElement = document.getElementById('totalCloudCoverSuccess');
            if (successElement) {
                const value = select.value;
                if (value === '0') {
                    successElement.textContent = '✓ السماء صافية';
                } else if (value === '9') {
                    successElement.textContent = '⚠ السماء مغطاة تماماً';
                } else if (value === '#') {
                    successElement.textContent = '❓ بيانات غير متوفرة';
                } else {
                    successElement.textContent = `✓ التغطية: ${value}/8`;
                }
                successElement.style.display = 'block';
            }
        } else {
            select.classList.remove('is-valid');
            select.classList.add('is-invalid');
            
            const errorElement = document.getElementById('totalCloudCoverError');
            if (errorElement) {
                errorElement.textContent = errorMessage;
                errorElement.style.display = 'block';
            }
            
            const successElement = document.getElementById('totalCloudCoverSuccess');
            if (successElement) successElement.style.display = 'none';
        }
    }

    showCoverageValidation(field, isValid, errorMessage = '') {
        if (isValid) {
            field.classList.remove('is-invalid');
            field.classList.add('is-valid');
        } else {
            field.classList.remove('is-valid');
            field.classList.add('is-invalid');
            
            const errorElement = document.getElementById(field.id + 'Error');
            if (errorElement) {
                errorElement.textContent = errorMessage;
                errorElement.style.display = 'block';
            }
        }
    }

    showSkyObscuredMessage(select) {
        const message = document.createElement('div');
        message.className = 'alert alert-warning alert-dismissible fade show mt-2';
        message.innerHTML = `
            <i class="fas fa-cloud-rain me-2"></i>
            <strong>السماء مغطاة تماماً!</strong> 
            تم تعطيل جميع حقول السحب لأن السماء مغطاة تماماً (القيمة 9).
            <br><small>لإعادة تفعيل الحقول، اختر أي قيمة أخرى من 0 إلى 8.</small>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        const cardField = select.closest('.card-field');
        if (cardField) {
            // إزالة الرسائل السابقة
            const oldMessages = cardField.querySelectorAll('.alert');
            oldMessages.forEach(msg => msg.remove());
            
            cardField.appendChild(message);
            
            setTimeout(() => {
                if (message.parentNode) {
                    message.remove();
                }
            }, 10000);
        }
    }

    showNotification(message, type = 'info') {
        const notificationContainer = document.getElementById('notificationContainer');
        if (!notificationContainer) {
            console.log(`${type}: ${message}`);
            return;
        }
        
        const alertClass = type === 'error' ? 'alert-danger' : 
                          type === 'success' ? 'alert-success' : 
                          type === 'warning' ? 'alert-warning' : 'alert-info';
        
        const notification = document.createElement('div');
        notification.className = `alert ${alertClass} alert-dismissible fade show`;
        notification.innerHTML = `
            <i class="fas ${type === 'success' ? 'fa-check-circle' : 
                          type === 'error' ? 'fa-exclamation-circle' : 
                          type === 'warning' ? 'fa-exclamation-triangle' : 
                          'fa-info-circle'} me-2"></i>
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        notificationContainer.appendChild(notification);
        
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, 5000);
    }
}

// تهيئة النظام عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        console.log('☁️ تهيئة نظام التغطية الكلية مع الخيارات المنسدلة...');
        window.cloudTotalCoverDropdown = new CloudTotalCoverDropdown();
    }, 1000);
});

// CSS إضافي
const cloudDropdownStyles = `
    .disabled-field {
        background-color: #f8f9fa !important;
        color: #6c757d !important;
        cursor: not-allowed !important;
        border-color: #dee2e6 !important;
        opacity: 0.7;
    }
    
    .cloud-field-obscured {
        background-color: #fff3cd !important;
        border-color: #ffc107 !important;
        text-decoration: line-through;
    }
    
    .has-hash {
        font-style: italic !important;
        color: #6c757d !important;
        background-color: #f8f9fa !important;
    }
    
    .sky-obscured-section {
        position: relative;
        transition: all 0.5s ease;
    }
    
    .sky-obscured-section::before {
        content: "السماء مغطاة تماماً";
        position: absolute;
        top: 10px;
        left: 10px;
        background-color: #ffc107;
        color: #856404;
        padding: 5px 10px;
        border-radius: 4px;
        font-size: 0.8rem;
        font-weight: bold;
        z-index: 1;
    }
    
    .sky-obscured-select {
        background-color: #fff3cd !important;
        border-color: #ffc107 !important;
        font-weight: bold !important;
        color: #856404 !important;
    }
    
    .field-status-icon {
        position: absolute;
        left: 10px;
        top: 50%;
        transform: translateY(-50%);
    }
    
    .cloud-layer h5.text-muted {
        color: #6c757d !important;
    }
    
    .cloud-layer h5.text-decoration-line-through {
        text-decoration: line-through !important;
    }
    
    /* تنسيق خيار 9 في القائمة المنسدلة */
    option[value="9"] {
        background-color: #fff3cd;
        color: #856404;
        font-weight: bold;
    }
    
    option[value="#"] {
        background-color: #f8f9fa;
        color: #6c757d;
        font-style: italic;
    }
    
    option[value="0"] {
        background-color: #d4edda;
        color: #155724;
    }
`;

// إضافة الأنماط إلى الصفحة
const styleSheet = document.createElement('style');
styleSheet.textContent = cloudDropdownStyles;
document.head.appendChild(styleSheet);