using System.Data;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Patients;

/// <summary>Finding and locking doctor–patient links and patient accounts inside a transaction.</summary>
public static class PatientLinks
{
    public static Task<bool> ExistsAsync(AppDbContext db, Guid doctorId, Guid patientId, CancellationToken cancellationToken) =>
        db.DoctorPatients.AnyAsync(l => l.DoctorId == doctorId && l.PatientId == patientId, cancellationToken);

    /// <summary>
    /// Reads the link with an update lock held until the transaction ends. Every write that depends on the
    /// link's counters (createSession, deleteSession) or rewrites its profile takes this lock first, so two of
    /// them for the same patient run one after the other (BR-S4, AC-2).
    /// </summary>
    public static Task<DoctorPatient?> LockAsync(AppDbContext db, Guid doctorId, Guid patientId, CancellationToken cancellationToken) =>
        db.DoctorPatients
            .FromSqlInterpolated($"SELECT * FROM [DoctorPatients] WITH (UPDLOCK, ROWLOCK) WHERE [DoctorId] = {doctorId} AND [PatientId] = {patientId}")
            .SingleOrDefaultAsync(cancellationToken);

    /// <summary>
    /// The patient account on this number, read with a key-range update lock (UPDLOCK, HOLDLOCK) on
    /// UQ_Patients_Phone: until the transaction ends nobody else can create an account on the number, so two
    /// clinics adding the same new number at once make one account and two links (BR-P2, BR-P3).
    /// </summary>
    public static Task<Patient?> LockByPhoneAsync(AppDbContext db, string phone, CancellationToken cancellationToken) =>
        db.Patients
            // VARCHAR, like the column: an NVARCHAR parameter would make SQL Server scan and lock the whole index.
            .FromSqlRaw(
                "SELECT * FROM [Patients] WITH (UPDLOCK, HOLDLOCK) WHERE [Phone] = @phone",
                new SqlParameter("@phone", SqlDbType.VarChar, 16) { Value = phone })
            .SingleOrDefaultAsync(cancellationToken);

    /// <summary>The patient with an update lock, for phone changes.</summary>
    public static Task<Patient> LockPatientAsync(AppDbContext db, Guid patientId, CancellationToken cancellationToken) =>
        db.Patients
            .FromSqlInterpolated($"SELECT * FROM [Patients] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {patientId}")
            .SingleAsync(cancellationToken);

    /// <summary>
    /// The doctor's next file number (BR-P6), with the doctor row update-locked until the transaction ends, so
    /// two patients added to one clinic at once get consecutive numbers. Call <see cref="TakeFileNumberAsync"/>
    /// when the link is saved.
    /// </summary>
    public static async Task<int> LockNextFileNumberAsync(AppDbContext db, Guid doctorId, CancellationToken cancellationToken) =>
        (await db.Database
            .SqlQuery<int>($"SELECT [NextFileNumber] AS [Value] FROM [Doctors] WITH (UPDLOCK, ROWLOCK) WHERE [UserId] = {doctorId}")
            .ToListAsync(cancellationToken))
        .Single();

    public static Task TakeFileNumberAsync(AppDbContext db, Guid doctorId, int fileNumber, CancellationToken cancellationToken) =>
        db.Doctors.Where(d => d.UserId == doctorId)
            .ExecuteUpdateAsync(set => set.SetProperty(d => d.NextFileNumber, fileNumber + 1), cancellationToken);
}
