namespace El3yada.Api.Storage;

/// <summary>
/// A file the store refuses: <see cref="ErrorCodes.FileTooLarge"/>, <see cref="ErrorCodes.FileTypeNotAllowed"/>
/// or <see cref="ErrorCodes.FileContentInvalid"/>. Upload endpoints turn it into a 400 or 413 with the code.
/// </summary>
public sealed class FileStorageException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
}
