// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HoloDexCertificate (ERC-721)
 * @dev Sertifikat Keaslian & Riwayat Kepemilikan Kartu Pokémon TCG (HoloDex).
 * Dijalankan pada jaringan Polygon Testnet (Amoy).
 * Dilengkapi fungsi minting sertifikat dan pencatatan rantai kepemilikan (provenance).
 */

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract HoloDexCertificate {
    // Nama & Simbol Token ERC-721
    string public name = "HoloDex Card Certificate";
    string public symbol = "HDEX";

    // Alamat operator / platform owner yang berwenang menerbitkan sertifikat
    address public owner;
    uint256 private _tokenCounter;

    // Mapping ID Token ke Pemilik Alamat
    mapping(uint256 => address) private _owners;
    // Mapping Alamat ke Jumlah Token
    mapping(address => uint256) private _balances;
    // Mapping ID Token ke Card ID katalog HoloDex (misal: "swsh3-1")
    mapping(uint256 => string) private _cardIds;
    // Mapping ID Token ke Token URI (metadata JSON)
    mapping(uint256 => string) private _tokenURIs;
    // Mapping Operator Approval
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Struktur Data Riwayat Kepemilikan (Provenance Record)
    struct ProvenanceRecord {
        address from;
        address to;
        uint256 timestamp;
        uint256 priceIdr;
        string notes;
    }

    // Riwayat kepemilikan per Token ID
    mapping(uint256 => ProvenanceRecord[]) private _provenanceHistory;

    // Event Standar ERC-721
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // Event Khusus HoloDex Provenance
    event CertificateMinted(
        uint256 indexed tokenId,
        string cardId,
        address indexed initialOwner,
        string tokenURI
    );

    event ProvenanceRecorded(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 priceIdr,
        string notes
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "HoloDex: Hanya pemilik kontrak yang berwenang");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Alamat tidak valid");
        owner = newOwner;
    }

    function balanceOf(address account) external view returns (uint256) {
        require(account != address(0), "Alamat query tidak valid");
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Token belum dicetak / tidak valid");
        return tokenOwner;
    }

    function cardIdOf(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "Token tidak valid");
        return _cardIds[tokenId];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "Token tidak valid");
        return _tokenURIs[tokenId];
    }

    function totalCertificates() external view returns (uint256) {
        return _tokenCounter;
    }

    /**
     * @notice Minting Sertifikat Keaslian Baru untuk Kartu Pokémon.
     * @param recipient Alamat penerima / pemilik pertama sertifikat.
     * @param cardId ID kartu pada katalog HoloDex (contoh: "swsh3-1").
     * @param uri URI metadata kartu.
     */
    function mintCard(
        address recipient,
        string calldata cardId,
        string calldata uri
    ) external onlyOwner returns (uint256) {
        require(recipient != address(0), "Alamat penerima tidak boleh nol");

        _tokenCounter++;
        uint256 newTokenId = _tokenCounter;

        _owners[newTokenId] = recipient;
        _balances[recipient] += 1;
        _cardIds[newTokenId] = cardId;
        _tokenURIs[newTokenId] = uri;

        // Catat entri genesis di rantai kepemilikan
        _provenanceHistory[newTokenId].push(ProvenanceRecord({
            from: address(0),
            to: recipient,
            timestamp: block.timestamp,
            priceIdr: 0,
            notes: "Genesis Mint: Sertifikat Keaslian HoloDex Diterbitkan"
        }));

        emit Transfer(address(0), recipient, newTokenId);
        emit CertificateMinted(newTokenId, cardId, recipient, uri);

        return newTokenId;
    }

    /**
     * @notice Memindahkan sertifikat ke pemilik baru dan mencatat riwayat transaksi.
     * @param from Pemilik lama.
     * @param to Pemilik baru (pembeli).
     * @param tokenId ID Token sertifikat kartu.
     * @param priceIdr Harga transaksi dalam IDR.
     * @param notes Catatan transaksi (misal: "Marketplace Purchase").
     */
    function recordTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 priceIdr,
        string calldata notes
    ) external onlyOwner {
        require(_owners[tokenId] == from, "Pengirim bukan pemilik token");
        require(to != address(0), "Alamat penerima tidak valid");

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        _provenanceHistory[tokenId].push(ProvenanceRecord({
            from: from,
            to: to,
            timestamp: block.timestamp,
            priceIdr: priceIdr,
            notes: notes
        }));

        emit Transfer(from, to, tokenId);
        emit ProvenanceRecorded(tokenId, from, to, priceIdr, notes);
    }

    /**
     * @notice Mengambil jumlah entri riwayat perpindahan sertifikat.
     */
    function getProvenanceCount(uint256 tokenId) external view returns (uint256) {
        require(_owners[tokenId] != address(0), "Token tidak valid");
        return _provenanceHistory[tokenId].length;
    }

    /**
     * @notice Mengambil satu rekaman provenance berdasarkan indeks.
     */
    function getProvenanceEntry(uint256 tokenId, uint256 index) external view returns (
        address from,
        address to,
        uint256 timestamp,
        uint256 priceIdr,
        string memory notes
    ) {
        require(_owners[tokenId] != address(0), "Token tidak valid");
        require(index < _provenanceHistory[tokenId].length, "Indeks melampaui batas");
        ProvenanceRecord memory rec = _provenanceHistory[tokenId][index];
        return (rec.from, rec.to, rec.timestamp, rec.priceIdr, rec.notes);
    }
}
