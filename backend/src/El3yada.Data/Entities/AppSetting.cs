using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class AppSetting
{
    public byte Id { get; set; } = (byte)1;

    public int ExamFeePiasters { get; set; } = 3000;

    public int ConsultationFeePiasters { get; set; } = 1500;

    public int GracePeriodDays { get; set; } = 7;

    public int MaxConsecutiveConsultations { get; set; } = 2;

    public int MaxUploadMb { get; set; } = 50;

    public int MaxAssistantsPerDoctor { get; set; } = 5;

    public int MaxBranchesPerDoctor { get; set; } = 5;

    public string? InstapayAddress { get; set; }

    public string? InstapayAccountName { get; set; }

    public string? InstapayInstructionsAr { get; set; }

    public string? InstapayInstructionsEn { get; set; }

    public Guid? CurrentCatalogVersionId { get; set; }

    public string? SupportPhone { get; set; }

    public string? SupportWhatsapp { get; set; }

    public string? SupportEmail { get; set; }

    public string MinVersionAndroid { get; set; } = "0.0.0";

    public string MinVersionIos { get; set; } = "0.0.0";

    public string MinVersionWindows { get; set; } = "0.0.0";

    public string MinVersionMacos { get; set; } = "0.0.0";

    public bool MaintenanceEnabled { get; set; }

    public string? MaintenanceMessageAr { get; set; }

    public string? MaintenanceMessageEn { get; set; }

    public string? TermsAr { get; set; }

    public string? TermsEn { get; set; }

    public string? PrivacyAr { get; set; }

    public string? PrivacyEn { get; set; }

    public DateTime UpdatedAt { get; set; }

    public Guid? UpdatedBy { get; set; }

    public virtual CatalogVersion? CurrentCatalogVersion { get; set; }

    public virtual User? UpdatedByNavigation { get; set; }
}
