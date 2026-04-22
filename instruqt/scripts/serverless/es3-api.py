import os
import sys
import json
import time
import argparse
import requests
from typing import Dict, List, Optional, Any


"""
Elastic Cloud Serverless API Project Manager

This script provides functionality to manage Elastic Cloud Serverless projects via the API:
- Create new projects (elasticsearch, observability, security with extended options)
- Delete existing projects
- Update project configurations
- Reset project credentials

Enhanced Security Project Support:
- Admin Features Package: standard or enterprise
- Product Types: Configurable security, cloud, and endpoint product lines with complete or essentials tiers
- Search Lake: Data retention configuration (7-3681 days)
- Backward compatibility with existing simple Security project creation

The script is designed to be containerized and run in a Kubernetes environment,
accepting configuration via environment variables.

Usage:
    python elastic-cloud-serverless-api.py [--operation] [additional arguments]

Environment Variables:
    ELASTIC_API_KEY: API key for authentication
    ELASTIC_PROJECT_TYPE: Type of project (elasticsearch, observability, security)
    ELASTIC_REGIONS: Comma-separated list of regions to create projects in
    ELASTIC_OPERATION: Operation to perform (create, delete, update, reset-credentials, list)
    ELASTIC_PROJECT_NAME: Name of the project (for creation)
    ELASTIC_PROJECT_ID: ID of the project (for deletion/update)
    ELASTIC_OPTIMIZED_FOR: Optimization subtype (elasticsearch projects)
    ELASTIC_PRODUCT_TIER: Product tier (observability projects)
    ELASTIC_SECURITY_ADMIN_FEATURES: Admin features package (security projects)
    ELASTIC_SECURITY_SECURITY_TIER: Tier for the core security analytics line (security projects, values: complete, essentials, ai_soc)
    ELASTIC_SECURITY_CLOUD_TIER: Tier for the optional cloud protection line (security projects, set to 'complete', 'essentials', or 'none' / leave unset to omit)
    ELASTIC_SECURITY_ENDPOINT_TIER: Tier for the optional endpoint protection line (security projects, set to 'complete', 'essentials', or 'none' / leave unset to omit)
    ELASTIC_SECURITY_MAX_RETENTION_DAYS: Maximum data retention days (7-3681) (security projects)
    ELASTIC_SECURITY_DEFAULT_RETENTION_DAYS: Default data retention days (7-3681) (security projects)
"""

# Valid values for API parameters based on Elastic Cloud Serverless API documentation
VALID_PROJECT_TYPES = ['elasticsearch', 'observability', 'security']
VALID_OPTIMIZED_FOR = ['general_purpose', 'vector']
VALID_PRODUCT_TIER = ['logs_essentials', 'complete']

# Extended Security Project Constants
VALID_SECURITY_ADMIN_FEATURES = ['standard', 'enterprise']
SECURITY_CORE_PRESETS = {
    'complete': {'product_line': 'security', 'product_tier': 'complete'},
    'essentials': {'product_line': 'security', 'product_tier': 'essentials'},
    'ai_soc': {'product_line': 'ai_soc', 'product_tier': 'search_ai_lake'}
}
SECURITY_CORE_CHOICES = list(SECURITY_CORE_PRESETS.keys())
OPTIONAL_SECURITY_TIERS = ['complete', 'essentials']
SECURITY_TIER_SKIP_VALUES = {'none', 'off', 'disable', 'disabled'}



def validate_project_type(project_type: str) -> bool:
    """
    Validate project type parameter

    Args:
        project_type: The project type to validate

    Returns:
        True if valid, False otherwise
    """
    if project_type not in VALID_PROJECT_TYPES:
        print(f"Error: Invalid project type '{project_type}'. Valid values are: {', '.join(VALID_PROJECT_TYPES)}")
        return False
    return True


def validate_optimized_for(optimized_for: str, project_type: str) -> bool:
    """
    Validate optimized_for parameter

    Args:
        optimized_for: The optimization type to validate
        project_type: The project type (optimized_for only applies to elasticsearch projects)

    Returns:
        True if valid, False otherwise
    """
    if optimized_for is None:
        return True  # Optional parameter

    if project_type != 'elasticsearch':
        print(
            f"Warning: optimized_for parameter is only applicable to 'elasticsearch' projects, not '{project_type}' projects. Ignoring this parameter.")
        return True

    if optimized_for not in VALID_OPTIMIZED_FOR:
        print(
            f"Error: Invalid optimized_for value '{optimized_for}'. Valid values are: {', '.join(VALID_OPTIMIZED_FOR)}")
        return False
    return True


def validate_product_tier(product_tier: str, project_type: str) -> bool:
    """
    Validate product_tier parameter

    Args:
        product_tier: The product tier to validate
        project_type: The project type (product_tier only applies to observability projects)

    Returns:
        True if valid, False otherwise
    """
    if product_tier is None:
        return True  # Optional parameter

    if project_type != 'observability':
        print(
            f"Warning: product_tier parameter is only applicable to 'observability' projects, not '{project_type}' projects. Ignoring this parameter.")
        return True

    if product_tier not in VALID_PRODUCT_TIER:
        print(f"Error: Invalid product_tier value '{product_tier}'. Valid values are: {', '.join(VALID_PRODUCT_TIER)}")
        return False
    return True


def validate_security_admin_features(admin_features: str, project_type: str) -> bool:
    """
    Validate admin_features_package parameter for Security projects

    Args:
        admin_features: The admin features package to validate
        project_type: The project type (admin_features only applies to security projects)

    Returns:
        True if valid, False otherwise
    """
    if admin_features is None:
        return True  # Optional parameter

    if project_type != 'security':
        print(
            f"Warning: admin_features_package parameter is only applicable to 'security' projects, not '{project_type}' projects. Ignoring this parameter.")
        return True

    if admin_features not in VALID_SECURITY_ADMIN_FEATURES:
        print(
            f"Error: Invalid admin_features_package value '{admin_features}'. Valid values are: {', '.join(VALID_SECURITY_ADMIN_FEATURES)}")
        return False
    return True


def validate_security_retention_days(retention_days: Optional[int], param_name: str) -> bool:
    """
    Validate security retention days parameter

    Args:
        retention_days: The retention days value to validate
        param_name: Parameter name for error messages

    Returns:
        True if valid, False otherwise
    """
    if retention_days is None:
        return True  # Optional parameter

    if not isinstance(retention_days, int) or retention_days < 7 or retention_days > 3681:
        print(f"Error: Invalid {param_name} value '{retention_days}'. Must be an integer between 7 and 3681 days.")
        return False
    return True


def build_security_product_types(security_tier: Optional[str],
                                 cloud_tier: Optional[str],
                                 endpoint_tier: Optional[str],
                                 project_type: str) -> Optional[List[Dict[str, str]]]:
    """
    Construct the Security product types payload from simple tier selections.

    Args:
        security_tier: Tier for the core security analytics line
        cloud_tier: Tier for the optional cloud protection line
        endpoint_tier: Tier for the optional endpoint protection line
        project_type: The project type

    Returns:
        List of product type objects or None if validation fails.
    """
    if project_type != 'security':
        if any([security_tier, cloud_tier, endpoint_tier]):
            print(
                f"Warning: Security tier parameters are only applicable to 'security' projects, not '{project_type}' projects. Ignoring these values.")
        return None

    product_types: List[Dict[str, str]] = []
    errors = False

    def normalize_optional_tier(raw_value: Optional[str], line: str) -> Optional[str]:
        nonlocal errors
        if raw_value is None or raw_value == '':
            return None  # omit optional line unless explicitly provided

        value = raw_value.strip().lower()

        if value in SECURITY_TIER_SKIP_VALUES:
            return None

        if value in OPTIONAL_SECURITY_TIERS:
            return value

        allowed = ", ".join(OPTIONAL_SECURITY_TIERS + ['none'])
        print(f"Error: Invalid tier '{raw_value}' for product line '{line}'. Valid values are: {allowed}.")
        errors = True
        return None

    core_value = (security_tier or '').strip().lower() or 'complete'
    core_profile = SECURITY_CORE_PRESETS.get(core_value)
    if not core_profile:
        allowed = ", ".join(SECURITY_CORE_PRESETS.keys())
        print(f"Error: Invalid security tier '{security_tier}'. Valid values are: {allowed}.")
        return None

    if core_profile['product_line'] == 'ai_soc':
        if cloud_tier and cloud_tier.strip().lower() not in SECURITY_TIER_SKIP_VALUES:
            print("Warning: Cloud protection tiers are ignored when the AI SOC Engine profile is selected.")
        if endpoint_tier and endpoint_tier.strip().lower() not in SECURITY_TIER_SKIP_VALUES:
            print("Warning: Endpoint protection tiers are ignored when the AI SOC Engine profile is selected.")
        cloud_normalized = None
        endpoint_normalized = None
    else:
        cloud_normalized = normalize_optional_tier(cloud_tier, 'cloud')
        endpoint_normalized = normalize_optional_tier(endpoint_tier, 'endpoint')

    if errors:
        return None

    product_types.append({'product_line': core_profile['product_line'],
                          'product_tier': core_profile['product_tier']})

    if cloud_normalized:
        product_types.append({'product_line': 'cloud', 'product_tier': cloud_normalized})

    if endpoint_normalized:
        product_types.append({'product_line': 'endpoint', 'product_tier': endpoint_normalized})

    if not product_types:
        print("Error: At least one security product line must be specified.")
        return None

    return product_types


class ElasticCloudClient:
    """Client for interacting with the Elastic Cloud Serverless API"""

    BASE_URL = "https://api.elastic-cloud.com/api/v1/serverless"

    def __init__(self, api_key: str):
        """
        Initialize the Elastic Cloud client

        Args:
            api_key: API key for authentication
        """
        self.api_key = api_key
        self.headers = {
            "Authorization": f"ApiKey {api_key}",
            "Content-Type": "application/json"
        }

    def create_project(self,
                       project_type: str,
                       name: str,
                       region_id: str,
                       alias: Optional[str] = None,
                       optimized_for: Optional[str] = None,
                       product_tier: Optional[str] = None,
                       # Security Project Extensions
                       security_admin_features: Optional[str] = None,
                       security_product_types: Optional[List[Dict[str, str]]] = None,
                       security_max_retention_days: Optional[int] = None,
                       security_default_retention_days: Optional[int] = None) -> Dict[str, Any]:
        """
        Create a new project with extended Security project support

        Args:
            project_type: Type of project (elasticsearch, observability, security)
            name: Project name
            region_id: Region ID (e.g., aws-us-east-1)
            alias: Custom domain label (optional)
            optimized_for: Optimization type (e.g., general_purpose for elasticsearch)
            product_tier: Product tier (e.g., logs_essentials for observability)
            security_admin_features: Admin features package (standard/enterprise for security)
            security_product_types: Product types configuration (for security)
            security_max_retention_days: Maximum retention days (for security)
            security_default_retention_days: Default retention days (for security)

        Returns:
            Response JSON from the API
        """
        url = f"{self.BASE_URL}/projects/{project_type}"

        payload = {
            "name": name,
            "region_id": region_id
        }

        if alias:
            payload["alias"] = alias

        if optimized_for and project_type == "elasticsearch":
            payload["optimized_for"] = optimized_for

        if product_tier and project_type == "observability":
            payload["product_tier"] = product_tier

        # Extended Security Project Configuration
        if project_type == "security":
            if security_admin_features:
                payload["admin_features_package"] = security_admin_features

            if security_product_types:
                payload["product_types"] = security_product_types  # type: ignore

            # Search Lake configuration for retention settings
            if security_max_retention_days is not None or security_default_retention_days is not None:
                search_lake = {}
                if security_max_retention_days is not None:
                    search_lake["max_retention_days"] = security_max_retention_days
                if security_default_retention_days is not None:
                    search_lake["default_retention_days"] = security_default_retention_days
                payload["search_lake"] = search_lake

        response = requests.post(url, headers=self.headers, json=payload)

        if response.status_code == 200 or response.status_code == 201:
            return response.json()
        else:
            print(f"Error creating project: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to create project: {response.text}")

    def delete_project(self, project_type: str, project_id: str) -> bool:
        """
        Delete an existing project

        Args:
            project_type: Type of project (elasticsearch, observability, security)
            project_id: Project ID to delete

        Returns:
            True if successful, raises an exception otherwise
        """
        url = f"{self.BASE_URL}/projects/{project_type}/{project_id}"

        response = requests.delete(url, headers=self.headers)

        if response.status_code == 200 or response.status_code == 204:
            return True
        else:
            print(f"Error deleting project: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to delete project: {response.text}")

    def update_project(self,
                       project_type: str,
                       project_id: str,
                       name: Optional[str] = None,
                       alias: Optional[str] = None,
                       if_match: Optional[str] = None) -> Dict[str, Any]:
        """
        Update an existing project

        Args:
            project_type: Type of project (elasticsearch, observability, security)
            project_id: Project ID to update
            name: New project name (optional)
            alias: New custom domain label (optional)
            if_match: ETag value from a previous GET request (for concurrency control)

        Returns:
            Response JSON from the API
        """
        url = f"{self.BASE_URL}/projects/{project_type}/{project_id}"

        payload = {}
        if name:
            payload["name"] = name
        if alias:
            payload["alias"] = alias

        headers = self.headers.copy()
        if if_match:
            headers["If-Match"] = if_match

        response = requests.patch(url, headers=headers, json=payload)

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error updating project: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to update project: {response.text}")

    def reset_credentials(self, project_type: str, project_id: str) -> Dict[str, Any]:
        """
        Reset project credentials

        Args:
            project_type: Type of project (elasticsearch, observability, security)
            project_id: Project ID

        Returns:
            Response JSON from the API with new credentials
        """
        url = f"{self.BASE_URL}/projects/{project_type}/{project_id}/_reset-credentials"

        response = requests.post(url, headers=self.headers)

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error resetting credentials: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to reset credentials: {response.text}")

    def get_project(self, project_type: str, project_id: str) -> Dict[str, Any]:
        """
        Get project details

        Args:
            project_type: Type of project (elasticsearch, observability, security)
            project_id: Project ID

        Returns:
            Response JSON from the API with project details
        """
        url = f"{self.BASE_URL}/projects/{project_type}/{project_id}"

        response = requests.get(url, headers=self.headers)

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error getting project: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to get project: {response.text}")

    def get_project_status(self, project_type: str, project_id: str) -> Dict[str, Any]:
        """
        Get project status

        Args:
            project_type: Type of project (elasticsearch, observability, security)
            project_id: Project ID

        Returns:
            Response JSON from the API with project status
        """
        url = f"{self.BASE_URL}/projects/{project_type}/{project_id}/status"

        response = requests.get(url, headers=self.headers)

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error getting project status: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to get project status: {response.text}")

    def list_projects(self, project_type: str, project_name: str = None) -> List[Dict[str, Any]]:
        """
        List all projects of a specific type

        Args:
            project_type: Type of project (elasticsearch, observability, security)

        Returns:
            List of projects
        """
        url = f"{self.BASE_URL}/projects/{project_type}"

        response = requests.get(url, headers=self.headers)

        output = response.json()
        if project_name is not None:
            output = {"items": []}
            ids = []
            for project in response.json()['items']:
                if project_name in project['name']:
                    output["items"].append(project)
                    ids.append(project['id'])
            #print(json.dumps(ids))

        if response.status_code == 200:
            return output
        else:
            print(f"Error listing projects: {response.status_code}")
            print(response.text)
            raise Exception(f"Failed to list projects: {response.text}")


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Elastic Cloud Serverless API Project Manager - Extended Security Edition')

    parser.add_argument('--operation', choices=['create', 'delete', 'update', 'reset-credentials', 'list'],
                        help='Operation to perform')

    parser.add_argument('--project-type', choices=VALID_PROJECT_TYPES,
                        help=f'Type of project. Valid values: {", ".join(VALID_PROJECT_TYPES)}')

    parser.add_argument('--regions', help='Comma-separated list of regions')

    parser.add_argument('--project-name', help='Name of the project (for creation)')

    parser.add_argument('--project-id', help='ID of the project (for deletion/update)')

    parser.add_argument('--api-key', help='API key for authentication')

    parser.add_argument('--alias', help='Custom domain label (optional)')

    parser.add_argument('--optimized-for', choices=VALID_OPTIMIZED_FOR,
                        help=f'Optimization type (for elasticsearch projects only). Valid values: {", ".join(VALID_OPTIMIZED_FOR)}')

    parser.add_argument('--product-tier', choices=VALID_PRODUCT_TIER,
                        help=f'Product tier (for observability projects only). Valid values: {", ".join(VALID_PRODUCT_TIER)}')

    # Extended Security Project Arguments
    parser.add_argument('--security-admin-features', choices=VALID_SECURITY_ADMIN_FEATURES,
                        help=f'Admin features package (for security projects only). Valid values: {", ".join(VALID_SECURITY_ADMIN_FEATURES)}')

    parser.add_argument('--security-security-tier', choices=SECURITY_CORE_CHOICES,
                        help=f'Tier for the core security analytics line (for security projects only). Valid values: {", ".join(SECURITY_CORE_CHOICES)}')

    optional_tier_choices = OPTIONAL_SECURITY_TIERS + ['none']

    parser.add_argument('--security-cloud-tier', choices=optional_tier_choices,
                        help=f'Tier for the optional cloud protection line (for security projects only). Valid values: {", ".join(optional_tier_choices)}')

    parser.add_argument('--security-endpoint-tier', choices=optional_tier_choices,
                        help=f'Tier for the optional endpoint protection line (for security projects only). Valid values: {", ".join(optional_tier_choices)}')

    parser.add_argument('--security-max-retention-days', type=int,
                        help='Maximum data retention days (for security projects only, 7-3681)')

    parser.add_argument('--security-default-retention-days', type=int,
                        help='Default data retention days (for security projects only, 7-3681)')

    parser.add_argument('--wait-for-ready', action='store_true',
                        help='Wait for the project to be fully initialized')

    return parser.parse_args()


def main():
    """Main function"""
    # Parse arguments from command line
    args = parse_args()

    # Environment variables have precedence over command line arguments
    api_key = os.environ.get('ELASTIC_API_KEY') or args.api_key
    project_type = os.environ.get('ELASTIC_PROJECT_TYPE') or args.project_type
    regions_str = os.environ.get('ELASTIC_REGIONS') or args.regions
    operation = os.environ.get('ELASTIC_OPERATION') or args.operation
    project_name = os.environ.get('ELASTIC_PROJECT_NAME') or args.project_name
    project_id = os.environ.get('ELASTIC_PROJECT_ID') or args.project_id
    alias = os.environ.get('ELASTIC_PROJECT_ALIAS') or args.alias
    optimized_for = os.environ.get('ELASTIC_OPTIMIZED_FOR') or args.optimized_for
    product_tier = os.environ.get('ELASTIC_PRODUCT_TIER') or args.product_tier
    wait_for_ready = os.environ.get('ELASTIC_WAIT_FOR_READY', 'false').lower() == 'true' or args.wait_for_ready

    # Extended Security Project Parameters
    security_admin_features = os.environ.get('ELASTIC_SECURITY_ADMIN_FEATURES') or args.security_admin_features
    security_security_tier = os.environ.get('ELASTIC_SECURITY_SECURITY_TIER') or args.security_security_tier
    security_cloud_tier = os.environ.get('ELASTIC_SECURITY_CLOUD_TIER') or args.security_cloud_tier
    security_endpoint_tier = os.environ.get('ELASTIC_SECURITY_ENDPOINT_TIER') or args.security_endpoint_tier
    security_max_retention_days = None
    security_default_retention_days = None

    # Handle retention days from environment or arguments
    if os.environ.get('ELASTIC_SECURITY_MAX_RETENTION_DAYS'):
        try:
            security_max_retention_days = int(os.environ.get('ELASTIC_SECURITY_MAX_RETENTION_DAYS'))
        except ValueError:
            print(f"Error: ELASTIC_SECURITY_MAX_RETENTION_DAYS must be an integer")
            sys.exit(1)
    elif args.security_max_retention_days:
        security_max_retention_days = args.security_max_retention_days

    if os.environ.get('ELASTIC_SECURITY_DEFAULT_RETENTION_DAYS'):
        try:
            security_default_retention_days = int(os.environ.get('ELASTIC_SECURITY_DEFAULT_RETENTION_DAYS'))
        except ValueError:
            print(f"Error: ELASTIC_SECURITY_DEFAULT_RETENTION_DAYS must be an integer")
            sys.exit(1)
    elif args.security_default_retention_days:
        security_default_retention_days = args.security_default_retention_days

    # Validate parameters
    if not api_key:
        print("Error: API key is required")
        sys.exit(1)

    if not operation:
        print("Error: Operation is required")
        sys.exit(1)

    if not project_type:
        print("Error: Project type is required")
        sys.exit(1)

    # Validate project_type
    if not validate_project_type(project_type):
        sys.exit(1)

    # Validate optimized_for (only for elasticsearch projects)
    if not validate_optimized_for(optimized_for, project_type):
        sys.exit(1)

    # Validate product_tier (only for observability projects)
    if not validate_product_tier(product_tier, project_type):
        sys.exit(1)

    # Validate Security project parameters
    if not validate_security_admin_features(security_admin_features, project_type):
        sys.exit(1)

    if not validate_security_retention_days(security_max_retention_days, "security_max_retention_days"):
        sys.exit(1)

    if not validate_security_retention_days(security_default_retention_days, "security_default_retention_days"):
        sys.exit(1)

    # Build Security product types payload
    security_product_types = build_security_product_types(
        security_security_tier,
        security_cloud_tier,
        security_endpoint_tier,
        project_type
    )
    if project_type == 'security' and security_product_types is None:
        sys.exit(1)

    if operation == 'create' and (not project_name or not regions_str):
        print("Error: Project name and regions are required for creation")
        sys.exit(1)

    if operation in ['delete', 'update', 'reset-credentials'] and not project_id:
        print(f"Error: Project ID is required for the {operation} operation")
        sys.exit(1)

    # Initialize Elastic client
    elastic_client = ElasticCloudClient(api_key)

    # Parse regions (trim whitespace and ignore empties)
    regions = [region.strip() for region in regions_str.split(',')] if regions_str else []
    regions = [region for region in regions if region]

    # Perform the requested operation
    try:
        if operation == 'create':
            if not regions:
                print("Error: At least one region is required for creation")
                sys.exit(1)

            # Create a project in each specified region
            results = {}
            for region in regions:
                print(f"Creating {project_type} project '{project_name}' in region {region}...")
                result = elastic_client.create_project(
                    project_type=project_type,
                    name=project_name,
                    region_id=region,
                    alias=alias,
                    optimized_for=optimized_for,
                    product_tier=product_tier,
                    # Extended Security Parameters
                    security_admin_features=security_admin_features,
                    security_product_types=security_product_types,
                    security_max_retention_days=security_max_retention_days,
                    security_default_retention_days=security_default_retention_days
                )

                project_id = result.get('id')
                if project_id and wait_for_ready:
                    print(f"Waiting for project {project_id} to be fully initialized...")
                    while True:
                        status = elastic_client.get_project_status(project_type, project_id)
                        if status.get('phase') == 'initialized':
                            print(f"Project {project_id} is now ready!")
                            break
                        print(f"Project status: {status.get('phase', 'unknown')}. Waiting...")
                        time.sleep(5)

                results[region] = result
                print(f"Successfully created project in {region}. Project ID: {project_id}")

                # Print out important details
                if 'endpoints' in result:
                    print("\nEndpoints:")
                    for service, url in result['endpoints'].items():
                        print(f"  {service}: {url}")

                if 'credentials' in result:
                    print("\nCredentials:")
                    print(f"  Username: {result['credentials'].get('username', 'N/A')}")
                    print(f"  Password: {result['credentials'].get('password', 'N/A')}")

                print(f"\nCloud ID: {result.get('cloud_id', 'N/A')}")

                # Print Security project specific details
                if project_type == 'security':
                    if security_admin_features:
                        print(f"Admin Features Package: {security_admin_features}")
                    if security_product_types:
                        print(f"Product Types Configuration:")
                        for pt in security_product_types:
                            print(f"  - {pt['product_line']}: {pt['product_tier']}")
                    if security_max_retention_days or security_default_retention_days:
                        print("Data Retention Settings:")
                        if security_max_retention_days:
                            print(f"  Maximum Retention: {security_max_retention_days} days")
                        if security_default_retention_days:
                            print(f"  Default Retention: {security_default_retention_days} days")

                print("=" * 80)

            # Write results to a file that could be used by another process
            with open('/tmp/project_results.json', 'w') as f:
                json.dump(results, f, indent=2)

        elif operation == 'delete':
            if not project_id:
                print("Error: Project ID is required for deletion")
                sys.exit(1)

            project_ids = project_id.split(',')
            for id in project_ids:
                print(f"Deleting {project_type} project {id}...")
                result = elastic_client.delete_project(project_type, id)
                if result:
                    print(f"Successfully deleted project {id}")

        elif operation == 'update':
            if not project_id:
                print("Error: Project ID is required for update")
                sys.exit(1)

            print(f"Updating {project_type} project {project_id}...")
            result = elastic_client.update_project(
                project_type=project_type,
                project_id=project_id,
                name=project_name,
                alias=alias
            )
            print(f"Successfully updated project {project_id}")
            print(json.dumps(result, indent=2))

        elif operation == 'reset-credentials':
            if not project_id:
                print("Error: Project ID is required for resetting credentials")
                sys.exit(1)

            print(f"Resetting credentials for {project_type} project {project_id}...")
            result = elastic_client.reset_credentials(project_type, project_id)
            print(f"Successfully reset credentials for project {project_id}")

            # The reset-credentials API returns credentials directly in the response
            if 'username' in result and 'password' in result:
                print("\nNew Credentials:")
                print(f"  Username: {result.get('username', 'N/A')}")
                print(f"  Password: {result.get('password', 'N/A')}")

        elif operation == 'list':
            print(f"Listing all {project_type} projects...")
            result = elastic_client.list_projects(project_type, project_name)
            print(json.dumps(result, indent=2))

        else:
            print(f"Unknown operation: {operation}")
            sys.exit(1)

    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()