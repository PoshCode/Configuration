Add-Type -TypeDefinition @'
public interface IPsMetadataSerializable {
    string ToPsMetadata();
    void FromPsMetadata(string Metadata);
}
'@